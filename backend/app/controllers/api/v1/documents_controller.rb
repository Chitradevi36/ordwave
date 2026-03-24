# ── Document Generation & Management API Controller ────────────────────────────
# Endpoints for generating, retrieving, and managing documents

module Api
  module V1
    class DocumentsController < BaseController
      before_action :require_organization!
      before_action :set_document, only: %i[show download regenerate archive]

      # ── List Documents ─────────────────────────────────────────────────────────
      # GET /api/v1/documents
      #
      # Query Parameters:
      #   - type: Filter by document type (invoice, waybill, etc.)
      #   - status: Filter by status (generated, regenerated, archived)
      #   - reference_id: Filter by reference (Sales Order ID, Trip ID, etc.)
      #   - start_date: Filter from date (ISO format)
      #   - end_date: Filter to date (ISO format)
      #   - page: Pagination page (default: 1)
      #
      # @return [200] { documents: Array, meta: { total, page, per_page } }
      def index
        scope = Document.for_org(current_organization.id).active.recent

        scope = scope.by_type(params[:type]) if params[:type].present?
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.for_reference(params[:reference_id]) if params[:reference_id].present?

        if params[:start_date].present? && params[:end_date].present?
          scope = scope.by_date_range(
            Date.parse(params[:start_date]),
            Date.parse(params[:end_date])
          )
        end

        documents = paginate(scope)

        render_success(
          documents.map { |d| serialize_document(d) },
          meta: pagination_meta(documents)
        )
      end

      # ── Get Document Details ───────────────────────────────────────────────────
      # GET /api/v1/documents/:id
      #
      # @return [200] Document details with size and metadata
      def show
        render_success(serialize_document(@document, detailed: true))
      end

      # ── Generate Document ─────────────────────────────────────────────────────
      # POST /api/v1/documents/generate
      #
      # Body:
      # {
      #   "type": "invoice" | "waybill" | "ewaybill" | "delivery_receipt" | "credit_note",
      #   "reference_id": "sales-invoice-123" (optional),
      #   "data": {
      #     "invoice_id": "INV-001",
      #     "amount": 15000,
      #     "customer": {...},
      #     "items": [...]
      #   }
      # }
      #
      # @return [201] Created document with download URL
      def generate
        type = params.require(:type)
        reference_id = params[:reference_id]
        data = params.require(:data)

        begin
          generator = DocumentGeneratorService.new

          document = generator.generate_and_save(
            type.to_sym,
            data.to_h,
            current_organization.id,
            { reference_id:, user_id: current_user.id }
          )

          render_created({
            id: document.id,
            filename: document.filename,
            size: document.size_bytes,
            download_url: api_v1_document_download_url(document),
            type: document.document_type,
            created_at: document.created_at
          })
        rescue DocumentGeneratorService::InvalidDocumentTypeError => e
          render_errors([e.message], status: :unprocessable_entity)
        rescue DocumentGeneratorService::RenderingError => e
          render_errors(["Document generation failed: #{e.message}"], status: :unprocessable_entity)
        rescue StandardError => e
          render_errors([e.message], status: :unprocessable_entity)
        end
      end

      # ── Download Document ─────────────────────────────────────────────────────
      # GET /api/v1/documents/:id/download
      #
      # Returns PDF file with proper content type and headers
      #
      # @return [200] PDF binary data
      def download
        authorize @document, :download?

        send_data @document.content,
                  filename: @document.filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      # ── Regenerate Document ────────────────────────────────────────────────────
      # PATCH /api/v1/documents/:id/regenerate
      #
      # Re-generates document (e.g., if template was updated)
      #
      # Body:
      # {
      #   "data": { updated template variables (optional) }
      # }
      #
      # @return [200] Regenerated document details
      def regenerate
        authorize @document, :regenerate?

        begin
          generator = DocumentGeneratorService.new
          updated_data = params[:data].present? ? params[:data].to_h : nil

          document = generator.regenerate(@document.id, updated_data)

          render_success({
            id: document.id,
            filename: document.filename,
            size: document.size_bytes,
            status: document.status,
            updated_at: document.updated_at
          })
        rescue StandardError => e
          render_errors([e.message], status: :unprocessable_entity)
        end
      end

      # ── Archive Document ───────────────────────────────────────────────────────
      # DELETE /api/v1/documents/:id/archive
      #
      # Soft-deletes document (keeps for audit trail)
      #
      # @return [200] Confirmation message
      def archive
        authorize @document, :archive?

        @document.archive!

        render_success({ message: 'Document archived', archived_at: @document.archived_at })
      end

      # ── Get Document Statistics ────────────────────────────────────────────────
      # GET /api/v1/documents/statistics
      #
      # Returns organization's document usage statistics
      #
      # @return [200] { total_count, by_type, total_size_mb, average_size_kb }
      def statistics
        stats = Document.stats_for_org(current_organization.id)

        render_success(stats)
      end

      # ── Batch Generate Documents ───────────────────────────────────────────────
      # POST /api/v1/documents/batch_generate
      #
      # Generates multiple documents in bulk
      #
      # Body:
      # {
      #   "type": "invoice",
      #   "documents": [
      #     { "data": {...} },
      #     { "data": {...} }
      #   ]
      # }
      #
      # @return [201] { generated: Int, failed: Int, documents: Array }
      def batch_generate
        type = params.require(:type)
        documents_data = params.require(:documents)

        begin
          generator = DocumentGeneratorService.new

          generated_docs = generator.batch_generate(
            type.to_sym,
            documents_data.map { |d| d[:data].to_h },
            current_organization.id
          )

          render_created({
            generated: generated_docs.count,
            failed: documents_data.count - generated_docs.count,
            documents: generated_docs.map { |d| serialize_document(d) }
          })
        rescue StandardError => e
          render_errors([e.message], status: :unprocessable_entity)
        end
      end

      private

      def set_document
        @document = Document.for_org(current_organization.id).find(params[:id])
        render_error('Document not found', status: :not_found) unless @document
      end

      def serialize_document(document, detailed: false)
        data = {
          id: document.id,
          type: document.document_type,
          filename: document.filename,
          size: document.size_bytes,
          size_formatted: document.size_formatted,
          status: document.status,
          created_at: document.created_at,
          download_url: api_v1_document_download_url(document),
        }

        if detailed
          data.merge({
            reference_id: document.reference_id,
            metadata: document.metadata,
            archived_at: document.archived_at,
            regenerated: document.regenerated?,
          })
        else
          data
        end
      end
    end
  end
end
