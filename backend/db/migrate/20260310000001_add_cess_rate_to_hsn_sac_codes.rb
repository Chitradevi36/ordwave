# frozen_string_literal: true

class AddCessRateToHsnSacCodes < ActiveRecord::Migration[7.1]
  def change
    add_column :hsn_sac_codes, :cess_rate, :decimal, precision: 5, scale: 2, default: 0.0, null: false
    add_column :hsn_sac_codes, :cess_type, :string, default: 'none', null: false # none, ad_valorem, specific, both
    add_column :hsn_sac_codes, :cess_specific_amount, :decimal, precision: 14, scale: 2 # per-unit cess (for specific cess)
  end
end
