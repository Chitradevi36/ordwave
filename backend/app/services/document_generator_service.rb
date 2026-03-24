# ── Document Generator Service ────────────────────────────────────────────────
# Generates professional PDFs for invoices, waybills, receipts, and credit notes

require 'wicked_pdf'

class DocumentGeneratorService
  # ── Document Types ────────────────────────────────────────────────────────────
  TYPES = {
    invoice: 'sales_invoice',
    waybill: 'waybill',
    ewaybill: 'ewaybill',
    delivery_receipt: 'delivery_receipt',
    credit_note: 'credit_note',
  }.freeze

  # ── Error Classes ─────────────────────────────────────────────────────────────
  class DocumentGeneratorError < StandardError; end
  class TemplateNotFoundError < DocumentGeneratorError; end
  class InvalidDocumentTypeError < DocumentGeneratorError; end
  class RenderingError < DocumentGeneratorError; end

  def initialize
    @wicked_pdf_options = {
      page_size: 'A4',
      margin: { top: 10, bottom: 10, left: 10, right: 10 },
      encoding: 'UTF-8',
      print_media_type: true,
      dpi: 300,
    }
  end

  # ── Generate Document ──────────────────────────────────────────────────────────
  #
  # Renders template to PDF and returns binary data
  #
  # @param type [Symbol] Document type: :invoice, :waybill, :ewaybill, etc.
  # @param data [Hash] Template variables
  #   - invoice_id, amount, items[], customer{}, organization{}, etc.
  # @param filename [String] Base filename for document
  # @return [String] PDF binary data
  #
  # Example:
  #   service = DocumentGeneratorService.new
  #   pdf_data = service.generate(:invoice, invoice_data, 'INV-001')
  #   File.write('invoice.pdf', pdf_data)
  def generate(type, data, filename = nil)
    validate_type!(type)
    validate_data!(data, type)

    begin
      html_content = render_template(type, data)
      pdf_data = WickedPdf.new.pdf_from_string(html_content, @wicked_pdf_options)

      track_generation(type, data, filename, pdf_data.bytesize)
      pdf_data
    rescue StandardError => e
      Rails.logger.error("[DocumentGenerator] Rendering failed: #{e.message}")
      raise RenderingError, "Failed to generate #{type} document: #{e.message}"
    end
  end

  # ── Generate and Save Document ─────────────────────────────────────────────────
  #
  # Generates PDF and saves to database + storage
  #
  # @param type [Symbol] Document type
  # @param data [Hash] Template variables
  # @param organization_id [String] Organization UUID
  # @param metadata [Hash] Additional metadata (reference_id, etc.)
  # @return [Document] Saved document record
  def generate_and_save(type, data, organization_id, metadata = {})
    validate_type!(type)

    filename = build_filename(type, data)
    pdf_data = generate(type, data, filename)

    # Extract reference_id from metadata if provided
    reference_id = metadata.delete(:reference_id)
    generated_by_user_id = metadata.delete(:user_id)

    document = Document.create!(
      organization_id:,
      reference_id:,
      document_type: type.to_s,
      filename:,
      size_bytes: pdf_data.bytesize,
      content: pdf_data,
      status: 'generated',
      generated_by_user_id:,
      metadata: metadata.merge({
        generated_at: Time.current.iso8601,
        template_version: '1.0',
      }),
    )

    document
  end

  # ── Get Document from Database ─────────────────────────────────────────────────
  #
  # Retrieves document PDF from storage
  #
  # @param document_id [String] Document UUID
  # @return [String] PDF binary data
  def retrieve(document_id)
    document = Document.find(document_id)
    raise DocumentGeneratorError, 'Document not found' unless document

    document.content
  end

  # ── Regenerate Document ────────────────────────────────────────────────────────
  #
  # Re-generates a document (e.g., if template was updated)
  #
  # @param document_id [String] Document UUID
  # @param updated_data [Hash] Updated template variables
  # @return [Document] Updated document record
  def regenerate(document_id, updated_data = nil)
    document = Document.find(document_id)
    raise DocumentGeneratorError, 'Document not found' unless document

    data = updated_data || document.metadata['original_data']
    pdf_data = generate(document.document_type.to_sym, data, document.filename)

    document.update!(
      content: pdf_data,
      size_bytes: pdf_data.bytesize,
      status: 'regenerated',
      updated_at: Time.current,
    )

    document
  end

  # ── Batch Generate Documents ───────────────────────────────────────────────────
  #
  # Generates multiple documents in bulk
  #
  # @param type [Symbol] Document type (same for all)
  # @param documents_data [Array<Hash>] Array of document data
  # @param organization_id [String] Organization UUID
  # @return [Array<Document>] Array of saved documents
  def batch_generate(type, documents_data, organization_id)
    generated_documents = []

    documents_data.each do |data|
      begin
        doc = generate_and_save(type, data, organization_id)
        generated_documents << doc
      rescue StandardError => e
        Rails.logger.error("[DocumentGenerator] Batch generation error: #{e.message}")
        # Continue with next document instead of failing entire batch
      end
    end

    generated_documents
  end

  private

  # ── Validate Document Type ─────────────────────────────────────────────────────
  def validate_type!(type)
    return if TYPES.keys.include?(type.to_sym)

    raise InvalidDocumentTypeError, "Unknown document type: #{type}. Valid types: #{TYPES.keys.join(', ')}"
  end

  # ── Validate Data for Template ────────────────────────────────────────────────
  def validate_data!(data, type)
    required_fields = case type.to_sym
                      when :invoice
                        %w[invoice_id amount customer organization items]
                      when :waybill, :ewaybill
                        %w[trip_id origin destination stops]
                      when :delivery_receipt
                        %w[stop_id customer verified_by timestamp]
                      when :credit_note
                        %w[credit_note_id amount reason]
                      else
                        []
                      end

    missing = required_fields - data.keys.map(&:to_s)
    raise ArgumentError, "Missing required fields: #{missing.join(', ')}" if missing.any?
  end

  # ── Render Template to HTML ────────────────────────────────────────────────────
  def render_template(type, data)
    template_path = Rails.root.join("app/views/documents/#{type}.html.erb")

    raise TemplateNotFoundError, "Template not found: #{template_path}" unless File.exist?(template_path)

    # Create a binding context with the data hash as local variables
    data_obj = Struct.new(*data.keys).new(*data.values)
    erb_binding = binding

    # Render template with locals
    template_content = File.read(template_path)
    erb = ERB.new(template_content)
    
    # Create a context where variables are accessible
    eval_context = Object.new
    data.each do |key, value|
      eval_context.instance_variable_set("@#{key}", value)
      eval_context.define_singleton_method(key) { instance_variable_get("@#{key}") }
    end
    
    erb.result(eval_context.instance_eval { binding })
  end

  # ── Build Filename ────────────────────────────────────────────────────────────
  def build_filename(type, data)
    prefix = case type.to_sym
             when :invoice
               "INV-#{data[:invoice_id]}"
             when :waybill
               "WB-#{data[:trip_id]}"
             when :ewaybill
               "EWB-#{data[:trip_id]}"
             when :delivery_receipt
               "DR-#{data[:stop_id]}"
             when :credit_note
               "CN-#{data[:credit_note_id]}"
             else
               "DOC-#{SecureRandom.hex(4)}"
             end

    "#{prefix}-#{Time.current.strftime('%Y%m%d-%H%M%S')}.pdf"
  end

  # ── Track Document Generation ─────────────────────────────────────────────────
  def track_generation(type, data, filename, size_bytes)
    Rails.logger.info(
      "[DocumentGenerator] Generated: type=#{type}, filename=#{filename}, size=#{size_bytes} bytes"
    )
  end
end
