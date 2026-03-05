class MakeSchemeApplicationSchemeIdNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :scheme_applications, :scheme_id, true
  end
end
