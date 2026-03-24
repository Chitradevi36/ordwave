namespace :documents do
  desc "Generate test document for a specific order"
  task :generate_for_order, [:order_id] => :environment do |t, args|
    order_id = args[:order_id]&.to_i || 36
    
    puts "Generating test invoice document for order ID: #{order_id}..."
    
    order = SalesOrder.find_by(id: order_id)
    if !order
      puts "❌ Order #{order_id} not found!"
      exit 1
    end
    
    organization = order.organization
    user = organization.users.first
    
    unless user
      puts "❌ No users found in organization!"
      exit 1
    end
    
    puts "Order: #{order.order_number}"
    puts "Organization: #{organization.name}"
    puts "User: #{user.name}"
    
    # Build invoice data
    invoice_data = {
      invoice_number: "INV-#{order.order_number}",
      order_number: order.order_number,
      customer_name: order.customer&.name || "Test Customer",
      customer_code: order.customer&.code || "CUST001",
      customer_address: "123 Test Street, Test City",
      customer_phone: "+91-9999999999",
      customer_gstin: "36AABCT1234H1Z5",
      
      organization_name: organization.name,
      organization_gstin: "36AABCT5678M1Z0",
      organization_phone: "+91-8888888888",
      
      order_date: order.created_at&.strftime("%d-%b-%Y") || Time.current.strftime("%d-%b-%Y"),
      invoice_date: Time.current.strftime("%d-%b-%Y"),
      invoice_number_display: "INV-#{Time.current.year}-0001",
      
      items: (order.lines || []).map do |line|
        {
          sn: line.id,
          description: line.product_name,
          hsn_code: line.hsn_code || "0000",
          qty: line.qty,
          unit: "pcs",
          rate: line.unit_price,
          amount: line.line_total,
          gst_rate: line.gst_rate || 18,
        }
      end,
      
      subtotal: (order.lines || []).sum { |l| l.qty * l.unit_price },
      gst_total: (order.lines || []).sum { |l| (l.qty * l.unit_price * (l.gst_rate || 18) / 100) },
      total_amount: order.total_amount,
      
      terms: "Payment terms: 15 days",
      notes: "Thank you for your business!",
    }
    
    begin
      generator = DocumentGeneratorService.new
      document = generator.generate_and_save(
        :invoice,
        invoice_data,
        organization.id,
        {
          reference_id: order.id,
          user_id: user.id,
        }
      )
      
      puts "✅ Document generated successfully!"
      puts "   ID: #{document.id}"
      puts "   Filename: #{document.filename}"
      puts "   Size: #{document.size_formatted}"
      puts "   Reference ID: #{document.reference_id}"
      puts "\nYou can now view this document in the order detail page."
    rescue => e
      puts "❌ Failed to generate document: #{e.message}"
      puts e.backtrace.join("\n")
      exit 1
    end
  end
end
