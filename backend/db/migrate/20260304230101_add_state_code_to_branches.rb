class AddStateCodeToBranches < ActiveRecord::Migration[7.1]
  def change
    # 2-digit GST state code (e.g. "27" for Maharashtra, "07" for Delhi)
    add_column :branches, :state_code, :string, limit: 2
    add_index  :branches, :state_code, name: 'index_branches_on_state_code'
  end
end
