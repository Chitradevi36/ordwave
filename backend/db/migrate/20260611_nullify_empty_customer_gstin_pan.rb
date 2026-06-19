class NullifyEmptyCustomerGstinPan < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    say_with_time "Converting empty GSTIN and PAN to NULL for customers" do
      execute <<~SQL
        UPDATE customers
        SET gstin = NULL
        WHERE gstin = '';
      SQL

      execute <<~SQL
        UPDATE customers
        SET pan = NULL
        WHERE pan = '';
      SQL
    end
  end

  def down
    # no-op: we don't revert NULLs back to empty strings
  end
end
