class OnboardingProgress < ApplicationRecord
  # Required steps for onboarding completion
  REQUIRED_STEPS = %w[
    organization_setup
  ].freeze

  # Optional steps - user can complete anytime
  OPTIONAL_STEPS = %w[
    add_products
  ].freeze

  # All available steps
  CHECKLIST_STEPS = (REQUIRED_STEPS + OPTIONAL_STEPS).freeze

  belongs_to :organization
  belongs_to :user

  validates :organization_id, uniqueness: { scope: :user_id }

  before_create :initialize_steps
  after_save :handle_completion, if: :completed_just_now?

  def mark_step_complete!(step_name)
    raise ArgumentError, "Invalid step: #{step_name}" unless CHECKLIST_STEPS.include?(step_name.to_s)

    self.steps[step_name.to_s] = { 'completed' => true, 'completed_at' => Time.current.iso8601 }
    check_if_all_complete!
    save!
  end

  def step_completed?(step_name)
    steps.dig(step_name.to_s, 'completed') == true
  end

  def completion_percentage
    return 0 if steps.blank?
    # Only count required steps for completion percentage
    required_completed = REQUIRED_STEPS.count { |step| step_completed?(step) }
    (required_completed.to_f / REQUIRED_STEPS.size * 100).round
  end

  private

  def initialize_steps
    self.steps = CHECKLIST_STEPS.index_with { |_| { 'completed' => false, 'completed_at' => nil } }
  end

  def check_if_all_complete!
    # Onboarding is complete when ALL REQUIRED steps are done
    # Optional steps are ignored for completion check
    all_required_done = REQUIRED_STEPS.all? { |step| step_completed?(step) }
    
    if all_required_done
      self.completed = true
      self.completed_at = Time.current
    end
  end

  def completed_just_now?
    completed? && completed_changed? && saved_changes['completed']&.first == false
  end

  def handle_completion
    # Send congratulations email immediately
    OnboardingMailer.onboarding_complete(user, organization).deliver_later

    # Schedule reminder email for 48 hours later if they haven't added an order
    SendOnboardingReminderJob.set(wait: 48.hours).perform_later(organization.id)

    Rails.logger.info("[OnboardingProgress] Onboarding complete for org #{organization.id}. Reminder scheduled for 48 hours.")
  end
end
