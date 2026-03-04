class CreateOnboardingProgresses < ActiveRecord::Migration[7.1]
  def change
    create_table :onboarding_progresses do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user,         null: false, foreign_key: true
      t.jsonb      :steps,        default: {}, null: false
      t.boolean    :completed,    default: false, null: false
      t.datetime   :completed_at

      t.timestamps
    end

    add_index :onboarding_progresses, [:organization_id, :user_id], unique: true, name: 'idx_onboarding_org_user'
  end
end
