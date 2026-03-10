# Processes a data export request and attaches the resulting file to the Export record.
# Supports CSV and XLSX formats for: orders, invoices, payments, customers, inventory, beats.
#
class ExportJob < ApplicationJob
  queue_as :low

  retry_on StandardError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  # @param export_id [Integer]
  def perform(export_id)
    export = Export.find(export_id)

    Current.organization = export.organization
    Current.user         = export.requested_by

    export.mark_processing!

    data, headers = build_data(export)

    file_content, content_type, filename = if export.format == "xlsx"
      [build_xlsx(headers, data), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "#{export.export_type}_export_#{Date.current}.xlsx"]
    elsif export.format == "pdf"
      [build_pdf(export.export_type, headers, data), "application/pdf", "#{export.export_type}_export_#{Date.current}.pdf"]
    else
      [build_csv(headers, data), "text/csv", "#{export.export_type}_export_#{Date.current}.csv"]
    end

    export.file.attach(
      io:           StringIO.new(file_content),
      filename:     filename,
      content_type: content_type
    )

    export.mark_ready!(row_count: data.size)

    Rails.logger.info("[ExportJob] Export##{export_id} ready — #{data.size} rows")
  rescue => e
    export&.mark_failed!(e.message)
    Sentry.capture_exception(e) if defined?(Sentry)
    Rails.logger.error("[ExportJob] Export##{export_id} failed: #{e.message}")
    raise
  end

  private

  def build_data(export)
    org     = export.organization
    filters = export.filters.with_indifferent_access

    case export.export_type
    when "orders"
      scope = SalesOrder.where(organization: org)
      scope = scope.where(status: filters[:status]) if filters[:status]
      scope = scope.where("created_at >= ?", filters[:from_date]) if filters[:from_date]
      scope = scope.where("created_at <= ?", filters[:to_date])   if filters[:to_date]
      headers = %w[order_number status customer branch total_amount created_at]
      rows = scope.includes(:customer, :branch).map do |o|
        [o.order_number, o.status, o.customer.name, o.branch.name, o.total_amount, o.created_at.to_date]
      end
      [rows, headers]

    when "invoices"
      scope = SalesInvoice.where(organization: org)
      scope = scope.where(status: filters[:status]) if filters[:status]
      scope = scope.where("invoice_date >= ?", filters[:from_date]) if filters[:from_date]
      scope = scope.where("invoice_date <= ?", filters[:to_date])   if filters[:to_date]
      headers = %w[invoice_number status customer branch total_amount amount_paid invoice_date due_date]
      rows = scope.includes(:customer, :branch).map do |i|
        [i.invoice_number, i.status, i.customer.name, i.branch.name, i.total_amount, i.amount_paid, i.invoice_date, i.due_date]
      end
      [rows, headers]

    when "payments"
      scope = Payment.where(organization: org)
      scope = scope.where("payment_date >= ?", filters[:from_date]) if filters[:from_date]
      scope = scope.where("payment_date <= ?", filters[:to_date])   if filters[:to_date]
      headers = %w[payment_number status customer branch amount payment_mode payment_date]
      rows = scope.includes(:customer, :branch).map do |p|
        [p.payment_number, p.status, p.customer.name, p.branch.name, p.amount, p.payment_mode, p.payment_date]
      end
      [rows, headers]

    when "customers"
      scope = Customer.where(organization: org)
      headers = %w[name gstin phone email credit_limit outstanding city state]
      rows = scope.includes(:credit_account).map do |c|
        ca = c.credit_account
        [c.name, c.gstin, c.phone, c.email, ca&.credit_limit, ca&.current_balance, c.city, c.state]
      end
      [rows, headers]

    when "inventory"
      scope = InventoryLevel.where(organization: org)
      scope = scope.where(branch_id: filters[:branch_id]) if filters[:branch_id]
      headers = %w[sku product_name branch qty_on_hand qty_reserved qty_available low_stock]
      rows = scope.includes(:product, :branch).map do |il|
        [il.product.sku, il.product.name, il.branch.name, il.qty_on_hand, il.qty_reserved, il.qty_available, il.low_stock?]
      end
      [rows, headers]

    when "beats"
      scope = Beat.where(organization: org)
      headers = %w[name branch sales_rep active retailer_count]
      rows = scope.includes(:branch, :sales_rep).map do |b|
        [b.name, b.branch&.name, b.sales_rep&.email, b.active, b.try(:beat_retailers)&.count]
      end
      [rows, headers]

    else
      raise ArgumentError, "Unknown export_type: #{export.export_type}"
    end
  end

  def build_csv(headers, rows)
    require "csv"
    CSV.generate(headers: true) do |csv|
      csv << headers
      rows.each { |row| csv << row }
    end
  end

  def build_xlsx(headers, rows)
    package  = Axlsx::Package.new
    workbook = package.workbook
    workbook.add_worksheet do |sheet|
      sheet.add_row(headers, b: true)
      rows.each { |row| sheet.add_row(row) }
    end
    package.to_stream.read
  end

  def build_pdf(export_type, headers, rows)
    require "prawn"
    require "prawn/table"
    pdf = Prawn::Document.new(page_layout: :landscape, margin: 24)

    # Title
    pdf.font_size(14) { pdf.text export_type.capitalize + " Export — " + Date.current.to_s, style: :bold }
    pdf.move_down 8

    # Table
    table_data = [headers.map(&:humanize)] + rows.map { |r| r.map { |v| v.nil? ? "—" : v.to_s } }
    pdf.table(table_data,
      header:      true,
      row_colors:  ["FFFFFF", "F5F5F5"],
      cell_style:  { size: 8, padding: [4, 6] }) do
      row(0).font_style = :bold
      row(0).background_color = "1B4332"
      row(0).text_color = "FFFFFF"
    end

    pdf.render
  end
end
