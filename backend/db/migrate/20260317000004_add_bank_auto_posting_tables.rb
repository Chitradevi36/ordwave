class AddBankAutoPostingTables < ActiveRecord::Migration[7.1]
  def change
    # Table 1: auto_post_audits
    create_table :auto_post_audits do |t|
      t.bigint :payment_id, null: true
      t.bigint :bank_transaction_id, null: true
      t.jsonb :confidence_breakdown, default: {}, null: false
      t.boolean :auto_posted, default: false
      t.string :action, limit: 50, null: false  # 'auto_posted', 'rejected_by_finance', 'rejected_by_window'
      t.bigint :actor_id, null: true
      t.datetime :timestamp, null: false
      t.text :audit_notes

      t.timestamps
    end

    # Add foreign keys for auto_post_audits
    if table_exists?(:payments)
      add_foreign_key :auto_post_audits, :payments, if_not_exists: true
    end
    
    if table_exists?(:bank_transactions)
      add_foreign_key :auto_post_audits, :bank_transactions, if_not_exists: true
    end
    
    if table_exists?(:users)
      add_foreign_key :auto_post_audits, :users, column: :actor_id, if_not_exists: true
    end

    add_index :auto_post_audits, :payment_id, name: 'idx_auto_post_audits_payment_id'
    add_index :auto_post_audits, :bank_transaction_id, name: 'idx_auto_post_audits_bank_transaction_id'
    add_index :auto_post_audits, :action, name: 'idx_auto_post_audits_action'
    add_index :auto_post_audits, :timestamp, name: 'idx_auto_post_audits_timestamp'

    # Table 2: rejection_feedbacks
    create_table :rejection_feedbacks do |t|
      t.bigint :payment_id, null: false
      t.float :confidence_score
      t.string :rejection_reason, limit: 255
      t.datetime :timestamp, null: false

      t.timestamps
    end

    # Add foreign key for rejection_feedbacks
    if table_exists?(:payments)
      add_foreign_key :rejection_feedbacks, :payments, if_not_exists: true
    end

    add_index :rejection_feedbacks, :payment_id, name: 'idx_rejection_feedbacks_payment_id'
    add_index :rejection_feedbacks, :timestamp, name: 'idx_rejection_feedbacks_timestamp'

    # Table 3: confidence_adjustments (ML Model Configuration)
    create_table :confidence_adjustments do |t|
      t.float :amount_tolerance_pct, default: 2.0
      t.integer :date_tolerance_days, default: 3
      t.float :customer_fuzzy_minimum, default: 0.80
      t.integer :reference_weight, default: 15
      t.integer :auto_post_threshold, default: 95
      t.integer :suggestion_threshold, default: 85
      t.integer :rejection_window_minutes, default: 60
      t.integer :model_version, default: 1, null: false

      t.timestamps
    end

    add_index :confidence_adjustments, :model_version, unique: true, name: 'idx_confidence_adjustments_model_version'

    # Table 4: payment_suggestions
    create_table :payment_suggestions do |t|
      t.bigint :bank_transaction_id, null: false
      t.bigint :invoice_id, null: false
      t.float :confidence_score
      t.jsonb :confidence_breakdown, default: {}, null: false
      t.string :status, limit: 50, default: 'pending_approval'  # 'pending_approval', 'approved', 'rejected'
      t.bigint :approved_by
      t.datetime :approved_at

      t.timestamps
    end

    # Add foreign keys for payment_suggestions
    if table_exists?(:bank_transactions)
      add_foreign_key :payment_suggestions, :bank_transactions, if_not_exists: true
    end
    
    if table_exists?(:invoices)
      add_foreign_key :payment_suggestions, :invoices, if_not_exists: true
    end
    
    if table_exists?(:users)
      add_foreign_key :payment_suggestions, :users, column: :approved_by, if_not_exists: true
    end

    add_index :payment_suggestions, :status, name: 'idx_payment_suggestions_status'
    add_index :payment_suggestions, :bank_transaction_id, name: 'idx_payment_suggestions_bank_transaction_id'
    add_index :payment_suggestions, :invoice_id, name: 'idx_payment_suggestions_invoice_id'

    # Enhance payments table
    add_column :payments, :auto_posted, :boolean, default: false, if_not_exists: true
    add_column :payments, :confidence_score, :float, if_not_exists: true
    add_column :payments, :rejection_window_expires_at, :datetime, if_not_exists: true
    add_column :payments, :reversed_at, :datetime, if_not_exists: true
    add_column :payments, :reversed_by, :bigint, if_not_exists: true

    # Add foreign key constraint for reversed_by
    if table_exists?(:users)
      add_foreign_key :payments, :users, column: :reversed_by, if_not_exists: true
    end

    add_index :payments, [:auto_posted, :rejection_window_expires_at], 
              name: 'idx_payments_auto_posted_window', if_not_exists: true

    # Enhance bank_transactions table (if exists)
    if table_exists?(:bank_transactions)
      add_column :bank_transactions, :customer_name, :string, limit: 255, if_not_exists: true
      add_column :bank_transactions, :reference, :string, limit: 255, if_not_exists: true
      add_column :bank_transactions, :matched_confidence, :float, if_not_exists: true
      add_column :bank_transactions, :matched_invoice_id, :bigint, if_not_exists: true

      # Add foreign key constraint for matched_invoice_id (only if invoices table exists)
      if table_exists?(:invoices)
        add_foreign_key :bank_transactions, :invoices, column: :matched_invoice_id, if_not_exists: true
      end
    end

    # Insert default confidence adjustment configuration
    execute <<-SQL
      INSERT INTO confidence_adjustments (
        amount_tolerance_pct, 
        date_tolerance_days, 
        customer_fuzzy_minimum, 
        reference_weight, 
        auto_post_threshold, 
        suggestion_threshold, 
        rejection_window_minutes, 
        model_version, 
        created_at, 
        updated_at
      ) VALUES (
        2.0, 
        3, 
        0.80, 
        15, 
        95, 
        85, 
        60, 
        1, 
        NOW(), 
        NOW()
      )
      ON CONFLICT (model_version) DO NOTHING;
    SQL
  end
end
