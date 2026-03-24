#!/usr/bin/env rails runner

# Script to generate a test document for an existing order
# Usage: bundle exec rails runner db/scripts/generate_test_document.rb

order_id = 36  # SO-0020-000036
organization_id = 1  # Adjust based on your setup
user_id = 1  # Adjust based on your setup

order = SalesOrder.find(order_id) rescue nil
if !order
  puts "Order #{order_id} not found!"
  exit 1
end

puts "Generating test invoice document for Order #{order.order_number}..."

# Sample invoice data for the order
invoice_data = {
  invoice_number: "INV-#{order.order_number}",
  order_number: order.order_number,
  customer_name: order.customer&.name || "Test Customer",
  customer_code: order.customer&.code || "CUST001",
  customer_address: "123 Test Street, Test City",
  customer_phone: "+91-9999999999",
  customer_gstin: "36AABCT1234H1Z5",
  
  organization_name: "OrdWave Sample Org",
  organization_gstin: "36AABCT5678M1Z0",
  
  order_date: order.created_at&.strftime("%d-%b-%Y") || Time.current.strftime("%d-%b-%Y"),
  invoice_date: Time.current.strftime("%d-%b-%Y"),
  invoice_number_display: "INV-2026-0001",
  
  items: order.lines.map do |line|
    {
      sn: line.id,
      description: line.product_name,
      hsn_code: line.hsn_code || "0000",
      qty: line.qty,
      unit: "pcs",
      rate: line.unit_price,
      amount: line.line_total,
      gst_rate: line.gst_rate,
    }
  end,
  
  subtotal: order.lines.sum { |l| l.qty * l.unit_price },
  gst_total: order.lines.sum { |l| (l.qty * l.unit_price * l.gst_rate / 100) },
  total_amount: order.total_amount,
  
  terms: "Payment due within 15 days",
  notes: "Thank you for your business!",
}

begin
  generator = DocumentGeneratorService.new
  document = generator.generate_and_save(
    :invoice,
    invoice_data,
    organization_id,
    {
      reference_id: order.id,
      user_id:,
    }
  )
  
  puts "✓ Document generated successfully!"
  puts "  ID: #{document.id}"
  puts "  Filename: #{document.filename}"
  puts "  Size: #{document.size_formatted}"
  puts "  Reference ID: #{document.reference_id}"
rescue => e
  puts "✗ Failed to generate document: #{e.message}"
  puts e.backtrace.join("\n")
  exit 1
end
