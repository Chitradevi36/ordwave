class ChangeDunningAttemptsDefaultToHash < ActiveRecord::Migration[7.1]
  def up
    # The dunning_attempts column was created with a default of [] (Array),
    # but all code reads/writes it as a Hash keyed by "step_date" strings.
    # Fix the default to match code expectations.
    change_column_default :sales_invoices, :dunning_attempts, from: [], to: {}

    # Convert any existing Array values to empty Hash so running code works.
    execute <<~SQL
      UPDATE sales_invoices
         SET dunning_attempts = '{}'::jsonb
       WHERE jsonb_typeof(dunning_attempts) = 'array'
    SQL
  end

  def down
    change_column_default :sales_invoices, :dunning_attempts, from: {}, to: []
  end
end
