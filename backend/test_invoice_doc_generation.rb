#!/usr/bin/env rails runner

# Test automatic document generation for invoices

begin
  # Find an order we can use
  order = SalesOrder.find(36)
  puts "✓ Found order: #{order.order_number}"

  # Create an invoice from the order
  branch = order.branch
  customer = order.customer
  user = branch.organization.users.first

  puts "Creating invoice from order..."
  
  delivered_lines = order.lines.map do |line|
    {
      product_id:          line.product_id,
      qty:                 line.qty,
      sales_order_line_id: line.id,
      unit_price:          line.unit_price,
      discount_pct:        line.discount_pct,
      hsn_code:            line.hsn_code,
      gst_rate:            line.gst_rate
    }
  end

  result = Invoice::GenerateFromDeliveryService.call(
    actor:             user,
    branch:            branch,
    customer:          customer,
    sales_order:       order,
    invoice_date:      Date.current,
    generation_source: 'manual_from_order',
    delivered_lines:   delivered_lines
  )

  if result.success?
    invoice = result.invoice
    puts "\n✓ Invoice created!"
    puts "  Invoice #: #{invoice.invoice_number}"
    puts "  ID: #{invoice.id}"
    puts "  Amount: ₹#{invoice.grand_total}"
    puts "  Status: #{invoice.status}"
    
    # Wait a moment for the job to process (if using inline adapter)
    sleep(2)
    
    # Check if document was generated
    doc = Document.find_by(reference_id: invoice.id, document_type: 'invoice')
    if doc
      puts "\n✓ Document generated automatically!"
      puts "  Document ID: #{doc.id}"
      puts "  Filename: #{doc.filename}"
      puts "  Size: #{doc.size_formatted}"
    else
      puts "\n⏳ Document still pending (check Sidekiq)"
      puts "  Reference ID: #{invoice.id}"
    end
  else
    puts "✗ Failed to create invoice: #{result.errors.join(', ')}"
    exit 1
  end
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
