class AddReturnRequestIdToReturnRecords < ActiveRecord::Migration[7.1]
  def change
    add_reference :return_records, :return_request,
                  foreign_key: true,
                  null: true,
                  index: true
  end
end
