# frozen_string_literal: true

module Gst
  module Gstr1
    # Scans a **filed** GSTR-1 period and detects documents that have been
    # created or modified since filing, which would require a GSTR-1A amendment.
    #
    # The detector is idempotent — re-running it on the same period will not
    # create duplicate candidates.
    #
    # Usage:
    #   result = Gst::Gstr1::AmendmentDetector.call(
    #     organization:      org,
    #     gst_return_period: period   # must be filed?
    #   )
    #   result.success?     # => true
    #   result.candidates   # => [GstAmendmentCandidate, ...]
    #   result.counts       # => { new_invoice: 2, modified_invoice: 5, ... }
    #
    class AmendmentDetector
      DetectResult = Struct.new(
        :success,
        :period,
        :candidates,
        :counts,
        :errors,
        keyword_init: true
      ) do
        def success?
          success == true
        end
      end

      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(organization:, gst_return_period:)
        @organization = organization
        @period       = gst_return_period
      end

      def call
        unless @period.filed?
          return DetectResult.new(
            success:    false,
            period:     @period,
            candidates: [],
            counts:     {},
            errors:     ['Period must be filed before detecting amendments.']
          )
        end

        candidates = []
        candidates.concat detect_new_invoices
        candidates.concat detect_modified_invoices
        candidates.concat detect_cancelled_invoices
        candidates.concat detect_new_credit_notes
        candidates.concat detect_modified_credit_notes

        saved = candidates.map { |attrs| upsert_candidate!(attrs) }.compact

        DetectResult.new(
          success:    true,
          period:     @period,
          candidates: saved,
          counts:     tally(saved),
          errors:     []
        )
      rescue StandardError => e
        Rails.logger.error("[Gst::Gstr1::AmendmentDetector] #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
        DetectResult.new(
          success:    false,
          period:     @period,
          candidates: [],
          counts:     {},
          errors:     [e.message]
        )
      end

      private

      # ── Document detection ────────────────────────────────────────────────────

      def detect_new_invoices
        in_period_invoices
          .where('created_at > ?', filed_at)
          .map { |inv| build_attrs(:new_invoice, inv) }
      end

      def detect_modified_invoices
        in_period_invoices
          .where('updated_at > ? AND created_at <= ?', filed_at, filed_at)
          .map { |inv| build_attrs(:modified_invoice, inv) }
      end

      def detect_cancelled_invoices
        # Invoices whose date falls in this period that were voided/cancelled
        # after filing
        base_invoice_scope
          .where(status: %w[voided cancelled])
          .where('updated_at > ?', filed_at)
          .map { |inv| build_attrs(:cancelled_invoice, inv) }
      end

      def detect_new_credit_notes
        # Credit notes created after filing, linked to an invoice in this period
        base_credit_note_scope
          .where('credit_notes.created_at > ?', filed_at)
          .map { |cn| build_attrs(:new_cn, cn) }
      end

      def detect_modified_credit_notes
        base_credit_note_scope
          .where('credit_notes.updated_at > ? AND credit_notes.created_at <= ?',
                 filed_at, filed_at)
          .map { |cn| build_attrs(:modified_cn, cn) }
      end

      # ── Scopes ────────────────────────────────────────────────────────────────

      def in_period_invoices
        base_invoice_scope.where(status: %w[issued partially_paid paid])
      end

      def base_invoice_scope
        SalesInvoice
          .where(organization: @organization)
          .where(invoice_date: period_range)
      end

      # Credit notes that are issued and whose linked invoice falls in the period.
      # Falls back to a date-range approach if the association is not present.
      def base_credit_note_scope
        if credit_note_has_sales_invoice_join?
          # Join via direct foreign key on credit notes table
          CreditNote
            .joins("INNER JOIN sales_invoices ON sales_invoices.id = credit_notes.sales_invoice_id")
            .where(organization: @organization, status: 'issued')
            .where(sales_invoices: { invoice_date: period_range })
        else
          # Fallback: credit notes whose issued_at falls within the period
          CreditNote
            .where(organization: @organization, status: 'issued')
            .where(issued_at: period_range)
        end
      end

      def credit_note_has_sales_invoice_join?
        CreditNote.column_names.include?('sales_invoice_id')
      rescue StandardError
        false
      end

      # ── Builders ──────────────────────────────────────────────────────────────

      def build_attrs(type, doc)
        current_taxable = doc.try(:subtotal).to_d
        current_tax     = doc.try(:tax_total).to_d

        summary = case type.to_s
                  when 'new_invoice'
                    "New Invoice: #{doc.try(:invoice_number)} (#{doc.try(:invoice_date)})"
                  when 'modified_invoice'
                    "Modified Invoice: #{doc.try(:invoice_number)} — updated #{doc.updated_at.to_date}"
                  when 'cancelled_invoice'
                    "Cancelled Invoice: #{doc.try(:invoice_number)}"
                  when 'new_cn'
                    "New Credit Note: #{doc.try(:credit_note_number)}"
                  when 'modified_cn'
                    "Modified Credit Note: #{doc.try(:credit_note_number)}"
                  else
                    "#{type}: #{doc.id}"
                  end

        {
          organization:          @organization,
          gst_return_period:     @period,
          source_type:           doc.class.name,
          source_id:             doc.id,
          amendment_type:        type.to_s,
          status:                'detected',
          detected_at:           Time.current,
          taxable_value_current: current_taxable,
          tax_current:           current_tax,
          change_summary:        summary,
          metadata:              { detected_by: 'AmendmentDetector', period_filed_at: filed_at.iso8601 }
        }
      end

      # ── Persistence ───────────────────────────────────────────────────────────

      # Creates a new candidate or returns the existing one — idempotent.
      def upsert_candidate!(attrs)
        existing = GstAmendmentCandidate.find_by(
          gst_return_period: attrs[:gst_return_period],
          source_type:       attrs[:source_type],
          source_id:         attrs[:source_id]
        )
        return existing if existing

        GstAmendmentCandidate.create!(attrs)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn("[AmendmentDetector] Skipping invalid candidate: #{e.message}")
        nil
      end

      # ── Helpers ───────────────────────────────────────────────────────────────

      def filed_at
        @filed_at ||= @period.filed_at || @period.updated_at
      end

      def period_range
        @period_range ||= begin
          from = Date.new(@period.year, @period.month, 1)
          to   = from.end_of_month
          from..to
        end
      end

      def tally(candidates)
        candidates.compact.group_by(&:amendment_type).transform_values(&:count)
      end
    end
  end
end
