# == Schema Information
#
# Table name: collection_schedules
#
#  id                   :bigint           not null, primary key
#  organization_id      :bigint           not null
#  branch_id            :bigint           not null
#  customer_id          :bigint           not null
#  assigned_to_id       :bigint           not null
#  scheduled_date       :date             not null
#  amount_expected      :decimal(12, 2)   not null, default(0.0)
#  status               :string           not null, default("planned")
#  notes                :text
#  completed_payment_id :bigint
#  rescheduled_to       :date
#  skip_reason          :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null

class CollectionSchedule < ApplicationRecord
  STATUSES = %w[planned completed partial skipped rescheduled].freeze

  # ── Associations ──────────────────────────────────────────────────────────
  belongs_to :organization
  belongs_to :branch
  belongs_to :customer
  belongs_to :assigned_to, class_name: "User"
  belongs_to :completed_payment, class_name: "Payment", optional: true

  # ── Validations ───────────────────────────────────────────────────────────
  validates :scheduled_date, presence: true
  validates :amount_expected, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }

  # ── Scopes ────────────────────────────────────────────────────────────────
  scope :for_organization, ->(org_id)    { where(organization_id: org_id) }
  scope :for_branch,       ->(branch_id) { where(branch_id: branch_id) }
  scope :for_user,         ->(user_id)   { where(assigned_to_id: user_id) }
  scope :for_customer,     ->(cust_id)   { where(customer_id: cust_id) }
  scope :for_date,         ->(date)      { where(scheduled_date: date) }
  scope :for_date_range,   ->(from, to)  { where(scheduled_date: from..to) }

  scope :planned,     -> { where(status: "planned") }
  scope :completed,   -> { where(status: "completed") }
  scope :skipped,     -> { where(status: "skipped") }
  scope :rescheduled, -> { where(status: "rescheduled") }

  scope :upcoming,         -> { planned.where("scheduled_date >= ?", Date.current) }
  scope :overdue_planned,  -> { planned.where("scheduled_date < ?", Date.current) }
  scope :today,            -> { for_date(Date.current) }
  scope :this_week,        -> { for_date_range(Date.current.beginning_of_week, Date.current.end_of_week) }

  # ── Instance Methods ──────────────────────────────────────────────────────

  def complete!(payment)
    update!(
      status:              "completed",
      completed_payment:   payment
    )
  end

  def partial!(payment)
    update!(
      status:            "partial",
      completed_payment: payment
    )
  end

  def skip!(reason)
    update!(
      status:      "skipped",
      skip_reason: reason
    )
  end

  def reschedule!(new_date)
    update!(
      status:          "rescheduled",
      rescheduled_to:  new_date
    )
  end

  def planned?    = status == "planned"
  def completed?  = status == "completed"
  def skipped?    = status == "skipped"
  def rescheduled? = status == "rescheduled"
end
