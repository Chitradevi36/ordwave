# frozen_string_literal: true

module Api
  module V1
    class SupplierDebitNotesController < BaseController
      before_action :require_organization!
      before_action :set_debit_note, only: %i[show update issue void_note]

      # GET /api/v1/supplier_debit_notes
      def index
        base_scope = policy_scope(SupplierDebitNote).not_deleted.for_org(current_organization)
        scope      = base_scope.includes(:supplier, :branch, :return_request, :lines)
        scope      = apply_filters(scope)
        records    = paginate(scope.recent)

        counts = base_scope.group(:status).count

        render_success(
          records.map { |sdn| serialize_debit_note(sdn) },
          meta: pagination_meta(records).merge(counts: counts)
        )
      end

      # GET /api/v1/supplier_debit_notes/:id
      def show
        authorize @debit_note
        render_success(serialize_debit_note(@debit_note, detailed: true))
      end

      # POST /api/v1/supplier_debit_notes
      def create
        sdn = SupplierDebitNote.new(create_params.merge(
          organization: current_organization,
          created_by:   current_user,
          status:       'draft'
        ))

        authorize sdn

        if sdn.save
          sdn.recalculate_totals!
          render_created(serialize_debit_note(sdn.reload, detailed: true))
        else
          render_errors(sdn.errors.full_messages)
        end
      end

      # PATCH /api/v1/supplier_debit_notes/:id
      def update
        authorize @debit_note

        unless @debit_note.draft?
          return render_errors(['Only draft debit notes can be updated'])
        end

        if @debit_note.update(update_params)
          @debit_note.recalculate_totals!
          render_success(serialize_debit_note(@debit_note.reload, detailed: true))
        else
          render_errors(@debit_note.errors.full_messages)
        end
      end

      # POST /api/v1/supplier_debit_notes/:id/issue
      def issue
        authorize @debit_note, :issue?

        if @debit_note.issued?
          return render_errors(['Debit note is already issued'])
        end

        unless @debit_note.draft?
          return render_errors(['Only draft debit notes can be issued'])
        end

        @debit_note.issue!
        render_success(serialize_debit_note(@debit_note, detailed: true))
      end

      # POST /api/v1/supplier_debit_notes/:id/void
      def void_note
        authorize @debit_note, :void?

        unless @debit_note.issued?
          return render_errors(['Only issued debit notes can be voided'])
        end

        @debit_note.void!(params[:reason].presence || 'No reason provided')
        render_success(serialize_debit_note(@debit_note, detailed: true))
      end

      private

      def set_debit_note
        @debit_note = SupplierDebitNote.not_deleted
                                       .for_org(current_organization)
                                       .includes(:supplier, :branch, :return_request, lines: :product)
                                       .find(params[:id])
      end

      def apply_filters(scope)
        scope = scope.by_status(params[:status])        if params[:status].present?
        scope = scope.for_supplier(params[:supplier_id]) if params[:supplier_id].present?
        scope
      end

      def create_params
        params.permit(
          :branch_id, :supplier_id, :return_request_id,
          :debit_note_date, :reason, :notes,
          lines_attributes: %i[product_id qty unit_price gst_rate hsn_code notes]
        )
      end

      def update_params
        params.permit(
          :debit_note_date, :reason, :notes,
          lines_attributes: %i[id product_id qty unit_price gst_rate hsn_code notes _destroy]
        )
      end

      # ── Serializers ─────────────────────────────────────────────────────────

      def serialize_debit_note(sdn, detailed: false)
        data = {
          id:             sdn.id,
          note_number:    sdn.debit_note_number,
          note_date:      sdn.debit_note_date,
          status:         sdn.status,
          reason:         sdn.reason,
          subtotal:       sdn.subtotal,
          tax_total:      sdn.tax_total,
          total_amount:   sdn.total,
          currency:       'INR',
          notes:          sdn.notes,
          issued_at:      sdn.issued_at,
          voided_at:      sdn.voided_at,
          void_reason:    sdn.void_reason,
          created_at:     sdn.created_at,
          supplier: {
            id:    sdn.supplier_id,
            name:  sdn.supplier.name,
            code:  sdn.supplier.try(:code) || sdn.supplier.try(:supplier_code),
            gstin: sdn.supplier.try(:gstin)
          },
          branch: {
            id:   sdn.branch_id,
            name: sdn.branch.name,
            code: sdn.branch.code
          },
          # Supplier debit notes in this app are created from return requests.
          # The UI shows this as "Purchase Invoice" — we surface the return number
          # if available so the reference is traceable.
          purchase_invoice: sdn.return_request.present? ? {
            id:            sdn.return_request_id,
            invoice_number: sdn.return_request.return_number
          } : nil
        }

        if detailed
          data[:lines] = sdn.lines.map do |line|
            taxable = (line.qty.to_d * line.unit_price.to_d).round(2)
            {
              id:            line.id,
              product_id:    line.product_id,
              product_name:  line.product.name,
              product_sku:   line.product.sku,
              hsn_code:      line.hsn_code,
              qty:           line.qty,
              unit_price:    line.unit_price,
              taxable_value: taxable,
              gst_rate:      line.gst_rate,
              tax_amount:    line.tax_amount,
              line_total:    line.line_total,
              reason_code:   nil
            }
          end
        end

        data
      end
    end
  end
end
