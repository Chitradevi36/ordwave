class OnboardingProgress < ApplicationRecord
  CHECKLIST_STEPS = %w[
    setup_details
    add_first_product
    configure_pricing
    add_team_member
    create_first_order
    setup_payment_terms
  ].freeze

  belongs_to :organization
  belongs_to :user

  validates :organization_id, uniqueness: { scope: :user_id }

  before_create :initialize_steps

  def mark_step_complete!(step_name)
    raise ArgumentError, "Invalid step: #{step_name}" unless CHECKLIST_STEPS.include?(step_name.to_s)

    self.steps[step_name.to_s] = { completed: true, completed_at: Time.current.iso8601 }
    check_if_all_complete!
    save!
  end

  def step_completed?(step_name)
    steps.dig(step_name.to_s, 'completed') == true
  end

  def completion_percentage
    return 0 if steps.blank?
    completed_count = steps.values.count { |v| v['completed'] == true }
    (completed_count.to_f / CHECKLIST_STEPS.size * 100).round
  end

  private

  def initialize_steps
    self.steps = CHECKLIST_STEPS.index_with { |_| { completed: false, completed_at: nil } }
  end

  def check_if_all_complete!
    if steps.values.all? { |v| v['completed'] == true }
      self.completed = true
      self.completed_at = Time.current
    end
  end
end
