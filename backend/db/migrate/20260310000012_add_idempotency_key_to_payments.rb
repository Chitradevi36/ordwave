class AddIdempotencyKeyToPayments < ActiveRecord::Migration[7.1]
  def change
    add_column :payments, :idempotency_key, :string

    # Unique partial index — only enforced when the key is present
    add_index :payments, :idempotency_key,
              unique: true,
              where: "idempotency_key IS NOT NULL",
              name: "index_payments_on_idempotency_key"
  end
end
