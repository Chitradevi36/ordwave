class MakeCreditNotesReturnRequestNullable < ActiveRecord::Migration[7.1]
  # CRIT-02: The CreditNote model has `belongs_to :return_request, optional: true`
  # but the DB column was `null: false`.  This migration aligns the schema so
  # standalone / manual-adjustment credit notes can be created without a
  # ReturnRequest (adjustment_type: 'manual').
  def change
    change_column_null :credit_notes, :return_request_id, true
  end
end
