#!/usr/bin/env rails runner

begin
  order = SalesOrder.find(36)
  org = order.organization
  user = org.users.first

  unless user
    puts "✗ No users found in organization"
    exit 1
  end

  puts "Generating test invoice document..."
  puts "Order: #{order.order_number}"
  puts "Organization: #{org.name}"
  
  invoice_data = {
    invoice_id: "INV-#{order.order_number}",
    order_number: order.order_number,
    
    customer: {
      name: order.customer&.name || "Test Customer",
      code: order.customer&.code || "CUST001",
      address: "123 Test Street, Test City",
      phone: "+91-9999999999",
      gstin: "36AABCT1234H1Z5",
    },
    
    organization: {
      name: org.name,
      gstin: "36AABCT5678M1Z0",
      phone: "+91-8888888888",
    },
    
    amount: order.total_amount,
    
    items: order.lines.map do |l|
      {
        description: l.product&.name || "Product",
        qty: l.qty,
        rate: l.unit_price,
        amount: l.line_total,
        gst_rate: l.gst_rate || 18,
      }
    end,
    
    invoice_date: Time.current.strftime("%d-%b-%Y"),
  }

  generator = DocumentGeneratorService.new
  doc = generator.generate_and_save(:invoice, invoice_data, org.id, { reference_id: order.id, user_id: user.id })

  puts "✓ Document created!"
  puts "  ID: #{doc.id}"
  puts "  Reference ID: #{doc.reference_id}"
  puts "  Filename: #{doc.filename}"
  puts "  Size: #{doc.size_formatted}"
  
  count = Document.where(reference_id: 36).count
  puts "\nTotal documents for order 36: #{count}"
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
