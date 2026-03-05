class AddOutstandingToSalesInvoices < ActiveRecord::Migration[7.1]
  def change
    add_column :sales_invoices, :outstanding_amount, :decimal,
               precision: 14, scale: 2, default: '0.0', null: false,
               comment: 'Unpaid balance; decremented by payment allocations'

    add_column :sales_invoices, :paid_amount, :decimal,
               precision: 14, scale: 2, default: '0.0', null: false,
               comment: 'Sum of confirmed payment allocations'

    # Back-fill: for every issued invoice, outstanding = grand_total
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE sales_invoices
             SET outstanding_amount = grand_total,
                 paid_amount        = 0
           WHERE status IN ('issued', 'draft')
             AND deleted_at IS NULL;
        SQL
      end
    end

    add_index :sales_invoices, :outstanding_amount,
              name: 'idx_sales_invoices_outstanding'
  end
end
