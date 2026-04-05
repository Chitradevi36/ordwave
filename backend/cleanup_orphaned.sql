-- Clean up orphaned stock_movements records
DELETE FROM stock_movements 
WHERE reference_line_id NOT IN (
  SELECT id FROM sales_order_lines 
  WHERE id IS NOT NULL
) AND reference_line_id IS NOT NULL;
