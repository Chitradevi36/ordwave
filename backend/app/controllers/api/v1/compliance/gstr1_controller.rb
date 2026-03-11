# frozen_string_literal: true

module Api
  module V1
    module Compliance
      # Handles GSTR-1 preview and JSON export for GST compliance.
      #
      # GET  /api/v1/compliance/gstr1/preview           — Preview return data (human-readable).
      # GET  /api/v1/compliance/gstr1/export            — Download GST portal JSON file.
      # GET  /api/v1/compliance/gstr1/export_records    — List past export audit records.
      #
      # Query params for preview / export:
      #   month        1–12          (preferred — combined with year)
      #   year         YYYY          (preferred — combined with month)
      #   period_from  YYYY-MM-DD    (alternative explicit range start)
      #   period_to    YYYY-MM-DD    (alternative explicit range end)
      #   branch_id    optional      (scope to a single branch)
      #
      class Gstr1Controller < BaseController
        before_action :require_organization!
        # BaseController's verify_authorized is configured with `except: :index`.
        # Rails 7.1 raises if an action listed in :except doesn't exist on the subclass.
        # Since this controller has no :index action and each action calls authorize
        # explicitly, we skip both inherited Pundit after-action callbacks.
        skip_after_action :verify_authorized
        skip_after_action :verify_policy_scoped

        # GET /api/v1/compliance/gstr1/preview
        #
        # Returns a human-readable summary suitable for the compliance dashboard:
        #   {
        #     period, gstin,
        #     b2b:         [{ customer_name, gstin, invoice_count, taxable_value, tax_amount, total }],
        #     b2c:         [{ state, invoice_count, taxable_value, tax_amount, total }],
        #     cdnr:        [{ customer_name, gstin, note_count, taxable_value, tax_amount }],
        #     cdnur:       [{ note_count, taxable_value, tax_amount }],
        #     hsn_summary: [{ hsn_code, description, uqc, qty, taxable_value, igst, cgst, sgst, cess }],
        #     summary:     { total_invoices, total_credit_notes, total_taxable, total_tax, total_value },
        #     validation:  { valid, error_count, warning_count, errors, warnings }
        #   }
        def preview
          authorize :gstr1, :preview?

          result = build_service_result

          render_success(
            result.summary.merge(
              validation: validation_payload(result.validation_result)
            )
          )
        end

        # GET /api/v1/compliance/gstr1/export
        #
        # Generates the official GSTR-1 JSON used for GST portal upload and
        # returns it as a file attachment.  Also creates a Gstr1ExportRecord
        # audit row so managers can review past exports.
        #
        # Optional param:
        #   format  'json' (default) — reserved for future xlsx / pdf formats
        #
        def export
          authorize :gstr1, :export?

          result = build_service_result

          # Surface hard validation errors — export is blocked if seller GSTIN is missing.
          if result.validation_result.errors.any? { |e| e[:code] == 'MISSING_SELLER_GSTIN' }
            return render_errors(
              ['Organisation GSTIN is not configured. Cannot generate GSTR-1.'],
              status: :unprocessable_entity
            )
          end

          portal_json = result.portal_json
          filename    = "GSTR1_#{current_organization.gst_number}_#{period_from.strftime('%m%Y')}.json"
          json_bytes  = JSON.pretty_generate(portal_json)

          # Record this export for audit purposes.
          record_export(result, filename)

          send_data json_bytes,
                    type:        'application/json',
                    disposition: "attachment; filename=\"#{filename}\""
        end

        # GET /api/v1/compliance/gstr1/export_records
        #
        # Lists past export audit records for the current organisation, newest first.
        # Accepts optional ?return_period=MMYYYY filter.
        #
        def export_records
          authorize :gstr1, :index?

          scope = Gstr1ExportRecord
            .for_org(current_organization)
            .recent

          scope = scope.for_period(params[:return_period]) if params[:return_period].present?
          scope = scope.where(branch_id: params[:branch_id]) if params[:branch_id].present?

          records = scope.limit(50)

          render_success(
            export_records: records.map { |r| serialize_export_record(r) }
          )
        end

        private

        # ── Service orchestration ───────────────────────────────────────────────

        def build_service_result
          Gst::Gstr1ExportService.call(
            organization: current_organization,
            period_from:  period_from,
            period_to:    period_to,
            branch_id:    params[:branch_id].presence
          )
        end

        # ── Period parsing ──────────────────────────────────────────────────────

        def period_from
          @period_from ||= begin
            if params[:period_from].present?
              Date.parse(params[:period_from])
            elsif params[:month].present? && params[:year].present?
              Date.new(params[:year].to_i, params[:month].to_i, 1)
            else
              Date.current.beginning_of_month
            end
          end
        end

        def period_to
          @period_to ||= begin
            if params[:period_to].present?
              Date.parse(params[:period_to])
            elsif params[:month].present? && params[:year].present?
              Date.new(params[:year].to_i, params[:month].to_i, 1).end_of_month
            else
              Date.current.end_of_month
            end
          end
        end

        # ── Audit record ────────────────────────────────────────────────────────

        def record_export(result, _filename)
          rec = Gstr1ExportRecord.create!(
            organization:  current_organization,
            branch_id:     params[:branch_id].presence,
            generated_by:  current_user,
            gstin:         current_organization.gst_number,
            return_period: period_from.strftime('%m%Y'),
            period_from:   period_from,
            period_to:     period_to,
            status:        'ready',
            completed_at:  Time.current,
            **result.counts.slice(:b2b, :b2cl, :b2cs, :cdnr, :cdnur)
              .transform_keys { |k| :"#{k}_count" },
            total_invoice_count: result.counts[:invoices],
            total_cn_count:      result.counts[:credit_notes],
            total_taxable_value: result.totals[:taxable],
            total_tax_value:     result.totals[:tax],
            total_invoice_value: result.totals[:total],
            error_count:         result.validation_result.error_count,
            warning_count:       result.validation_result.warning_count,
            validation_report:   {
              errors:   result.validation_result.errors,
              warnings: result.validation_result.warnings
            }
          )
          rec
        rescue StandardError => e
          Rails.logger.warn("Gstr1ExportRecord could not be saved: #{e.message}")
          nil
        end

        # ── Serializers ─────────────────────────────────────────────────────────

        def validation_payload(vr)
          {
            valid:         vr.valid?,
            error_count:   vr.error_count,
            warning_count: vr.warning_count,
            errors:        vr.errors,
            warnings:      vr.warnings
          }
        end

        def serialize_export_record(rec)
          {
            id:                  rec.id,
            return_period:       rec.return_period,
            period_from:         rec.period_from,
            period_to:           rec.period_to,
            status:              rec.status,
            b2b_count:           rec.b2b_count,
            b2cl_count:          rec.b2cl_count,
            b2cs_count:          rec.b2cs_count,
            cdnr_count:          rec.cdnr_count,
            total_invoice_count: rec.total_invoice_count,
            total_taxable_value: rec.total_taxable_value,
            total_tax_value:     rec.total_tax_value,
            error_count:         rec.error_count,
            warning_count:       rec.warning_count,
            generated_by:        rec.generated_by&.name,
            completed_at:        rec.completed_at
          }
        end
      end
    end
  end
end
