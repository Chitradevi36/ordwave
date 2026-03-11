# frozen_string_literal: true

module Gst
  module Gstr1
    # Builds a human-readable preview payload that maps directly onto the
    # frontend GSTR-1 preview page.
    #
    # The returned hash must match the TypeScript shape expected by
    # web/app/compliance/gstr1/page.tsx:
    #
    #   {
    #     period:      "2025-03",
    #     b2b:         [{ customer_name, gstin, invoice_count, taxable_value, tax_amount, total }],
    #     b2c:         [{ state, invoice_count, taxable_value, tax_amount, total }],
    #     cdnr:        [{ customer_name, gstin, note_count, taxable_value, tax_amount }],
    #     cdnur:       [{ note_count, taxable_value, tax_amount }],
    #     hsn_summary: [{ hsn_code, description, uqc, qty, taxable_value, igst, cgst, sgst, cess }],
    #     summary:     { total_invoices, total_taxable, total_tax, total_value }
    #   }
    #
    # Usage:
    #   SummaryBuilder.call(
    #     period_from:       Date,
    #     period_to:         Date,
    #     b2b_invoices:      [SalesInvoice, ...],
    #     b2cl_invoices:     [SalesInvoice, ...],
    #     b2cs_invoices:     [SalesInvoice, ...],
    #     cdnr_notes:        [CreditNote, ...],
    #     cdnur_notes:       [CreditNote, ...],
    #     seller_state_code: "27"
    #   )
    #
    class SummaryBuilder
      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(period_from:, period_to:, b2b_invoices:, b2cl_invoices:,
                     b2cs_invoices:, cdnr_notes:, cdnur_notes:, seller_state_code:)
        @period_from       = period_from
        @period_to         = period_to
        @b2b_invoices      = b2b_invoices
        @b2cl_invoices     = b2cl_invoices
        @b2cs_invoices     = b2cs_invoices
        @cdnr_notes        = cdnr_notes
        @cdnur_notes       = cdnur_notes
        @seller_state_code = seller_state_code
      end

      def call
        all_invoices    = @b2b_invoices + @b2cl_invoices + @b2cs_invoices
        all_credit_notes = @cdnr_notes + @cdnur_notes

        {
          period:      @period_from.strftime('%Y-%m'),
          gstin:       nil, # set at orchestration layer
          b2b:         build_b2b_summary,
          b2c:         build_b2c_summary,
          cdnr:        build_cdnr_summary,
          cdnur:       build_cdnur_summary,
          hsn_summary: build_hsn_summary(all_invoices, all_credit_notes),
          summary:     build_overall_summary(all_invoices, all_credit_notes)
        }
      end

      private

      # ── B2B: grouped by customer GSTIN ──────────────────────────────────────

      def build_b2b_summary
        @b2b_invoices.group_by { |inv| inv.customer.gstin }.map do |gstin, invs|
          {
            customer_name:  invs.first.customer.name,
            gstin:          gstin,
            invoice_count:  invs.size,
            taxable_value:  round(invs.sum { |inv| inv.subtotal.to_d }),
            tax_amount:     round(invs.sum { |inv| inv.tax_total.to_d }),
            total:          round(invs.sum { |inv| inv.grand_total.to_d })
          }
        end
      end

      # ── B2C: B2CL + B2CS grouped by state name ──────────────────────────────

      def build_b2c_summary
        all_b2c = @b2cl_invoices + @b2cs_invoices

        all_b2c.group_by { |inv| state_label_for(inv) }.map do |state, invs|
          {
            state:          state,
            invoice_count:  invs.size,
            taxable_value:  round(invs.sum { |inv| inv.subtotal.to_d }),
            tax_amount:     round(invs.sum { |inv| inv.tax_total.to_d }),
            total:          round(invs.sum { |inv| inv.grand_total.to_d })
          }
        end
      end

      # ── CDNR: credit notes to registered buyers ──────────────────────────────

      def build_cdnr_summary
        @cdnr_notes.group_by { |cn| cn.customer.gstin }.map do |gstin, notes|
          {
            customer_name: notes.first.customer.name,
            gstin:         gstin,
            note_count:    notes.size,
            taxable_value: round(notes.sum { |cn| taxable_of(cn) }),
            tax_amount:    round(notes.sum { |cn| cn.tax_total.to_d })
          }
        end
      end

      # ── CDNUR: credit notes to unregistered buyers ───────────────────────────

      def build_cdnur_summary
        return [] if @cdnur_notes.empty?

        [{
          note_count:    @cdnur_notes.size,
          taxable_value: round(@cdnur_notes.sum { |cn| taxable_of(cn) }),
          tax_amount:    round(@cdnur_notes.sum { |cn| cn.tax_total.to_d })
        }]
      end

      # ── HSN Summary ──────────────────────────────────────────────────────────

      def build_hsn_summary(all_invoices, all_credit_notes)
        hsn_data = {}

        all_invoices.each do |inv|
          is_inter = SectionClassifier.inter_state?(inv, seller_state_code: @seller_state_code)
          inv.lines.each { |line| accumulate_line(hsn_data, line, is_inter, sign: 1) }
        end

        # Credit notes are negative adjustments
        all_credit_notes.each do |cn|
          is_inter = cn.customer&.gstin.present? ?
                       @seller_state_code != cn.customer.gstin[0..1] : false
          cn.lines.each { |line| accumulate_credit_line(hsn_data, line, is_inter) }
        end

        hsn_data.values.map { |h| h.transform_values { |v| v.is_a?(BigDecimal) ? round(v) : v } }
      end

      def accumulate_line(hsn_data, line, is_inter, sign: 1)
        hsn = line.hsn_code.presence || line.product&.hsn_code.presence || 'UNKNOWN'
        uqc = line.product&.units_of_measure&.symbol || 'NOS'
        key = "#{hsn}_#{line.gst_rate}"

        hsn_data[key] ||= init_hsn_row(hsn, line, uqc)
        hsn_data[key][:qty]   += line.qty.to_d * sign
        hsn_data[key][:taxable_value] += line.taxable_value.to_d * sign

        if is_inter
          hsn_data[key][:igst] += line.igst_amount.to_d * sign
        else
          hsn_data[key][:cgst] += line.cgst_amount.to_d * sign
          hsn_data[key][:sgst] += line.sgst_amount.to_d * sign
        end
        hsn_data[key][:cess] += line.cess_amount.to_d * sign
      end

      def accumulate_credit_line(hsn_data, line, is_inter)
        hsn = line.hsn_code.presence || line.product&.hsn_code.presence || 'UNKNOWN'
        uqc = line.product&.units_of_measure&.symbol || 'NOS'
        key = "#{hsn}_#{line.gst_rate}"

        taxable = line.line_total.to_d - line.tax_amount.to_d
        tax     = line.tax_amount.to_d

        hsn_data[key] ||= init_hsn_row(hsn, line, uqc)
        hsn_data[key][:qty]           -= line.qty.to_d
        hsn_data[key][:taxable_value] -= taxable

        if is_inter
          hsn_data[key][:igst] -= tax
        else
          half = (tax / 2).round(2)
          hsn_data[key][:cgst] -= half
          hsn_data[key][:sgst] -= half
        end
      end

      def init_hsn_row(hsn, line, uqc)
        {
          hsn_code:      hsn,
          description:   line.product&.name.to_s.truncate(30),
          uqc:           uqc,
          qty:           BigDecimal('0'),
          taxable_value: BigDecimal('0'),
          igst:          BigDecimal('0'),
          cgst:          BigDecimal('0'),
          sgst:          BigDecimal('0'),
          cess:          BigDecimal('0')
        }
      end

      # ── Overall summary ──────────────────────────────────────────────────────

      def build_overall_summary(all_invoices, all_credit_notes)
        inv_taxable = all_invoices.sum { |inv| inv.subtotal.to_d }
        inv_tax     = all_invoices.sum { |inv| inv.tax_total.to_d }
        inv_total   = all_invoices.sum { |inv| inv.grand_total.to_d }

        cn_taxable  = all_credit_notes.sum { |cn| taxable_of(cn) }
        cn_tax      = all_credit_notes.sum { |cn| cn.tax_total.to_d }

        {
          total_invoices:     all_invoices.size,
          total_credit_notes: all_credit_notes.size,
          total_taxable:      round(inv_taxable - cn_taxable),
          total_tax:          round(inv_tax - cn_tax),
          total_value:        round(inv_total - all_credit_notes.sum { |cn| cn.total.to_d })
        }
      end

      # ── Helpers ──────────────────────────────────────────────────────────────

      def round(val)
        val.to_d.round(2).to_f
      end

      # CreditNote: taxable = total_before_tax. `subtotal` stores pre-tax value.
      def taxable_of(cn)
        cn.respond_to?(:subtotal) ? cn.subtotal.to_d : (cn.total.to_d - cn.tax_total.to_d)
      end

      # Inverse of SectionClassifier::STATE_CODE_MAP
      CODE_TO_STATE = SectionClassifier::STATE_CODE_MAP.invert

      # Returns a human-readable state label for a B2C invoice.
      # Falls back to the branch state name, then a titlised code, then 'Other'.
      def state_label_for(inv)
        pos        = SectionClassifier.place_of_supply_code(inv)
        from_code  = CODE_TO_STATE[pos]
        return from_code if from_code.present?

        # Try the branch state name directly
        branch_state = inv.try(:branch)&.state.to_s.strip
        return branch_state.split.map(&:capitalize).join(' ') if branch_state.present?

        pos == '00' ? 'Other' : pos
      end.freeze
    end
  end
end
