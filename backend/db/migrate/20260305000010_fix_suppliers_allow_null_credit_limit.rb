class FixSuppliersAllowNullCreditLimit < ActiveRecord::Migration[7.1]
  def change
    change_column_null    :suppliers, :credit_limit, true
    change_column_default :suppliers, :credit_limit, from: '0.0', to: nil
  end
end
