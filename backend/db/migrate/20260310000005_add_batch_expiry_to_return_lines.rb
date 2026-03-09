# frozen_string_literal: true

class AddBatchExpiryToReturnLines < ActiveRecord::Migration[7.1]
  def change
    add_column :return_lines, :batch_number, :string
    add_column :return_lines, :expiry_date, :date
    add_column :return_lines, :manufacture_date, :date
  end
end
