class CreateCreditAccounts < ActiveRecord::Migration[7.1]
  def change
    create_table :credit_accounts do |t|
      t.references :customer,    null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :branch,       null: false, foreign_key: true
      t.decimal :credit_limit,     precision: 12, scale: 2, default: 0, null: false
      t.decimal :current_balance,  precision: 12, scale: 2, default: 0, null: false
      t.decimal :available_credit, precision: 12, scale: 2, default: 0, null: false
      t.decimal :overdue_amount,   precision: 12, scale: 2, default: 0, null: false
      t.integer :overdue_days,     default: 0, null: false

      t.timestamps
    end
  end
end
