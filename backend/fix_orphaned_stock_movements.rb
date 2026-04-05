# Find orphaned records
puts "Finding orphaned stock_movements records..."
orphaned_ids = StockMovement.pluck(:reference_line_id).uniq - SalesOrderLine.pluck(:id)
puts "Orphaned reference_line_ids: #{orphaned_ids.inspect}"

# Delete them
if orphaned_ids.any?
  count = StockMovement.where(reference_line_id: orphaned_ids).delete_all
  puts "Deleted #{count} orphaned records"
else
  puts "No orphaned records found"
end
