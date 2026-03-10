class ChangeBeatRetailersSequenceNumberDefaultToOne < ActiveRecord::Migration[7.1]
  # LOW-07: sequence_number defaulted to 0 which made the "first customer of the
  # beat" display as #0 in driver/sales-rep apps.  Changing default to 1 matches
  # 1-based numbering used in the UI.  Existing rows with sequence_number = 0 get
  # bumped to 1 as part of this migration to avoid confusing display.
  def up
    change_column_default :beat_retailers, :sequence_number, from: 0, to: 1
    BeatRetailer.where(sequence_number: 0).update_all(sequence_number: 1)
  end

  def down
    change_column_default :beat_retailers, :sequence_number, from: 1, to: 0
  end
end
