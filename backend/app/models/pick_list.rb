# == Schema Information
# pick_lists: id, organization_id, branch_id, sales_order_id, picker_id,
#             status, pick_number, started_at, completed_at, created_at, updated_at
class PickList < ApplicationRecord
  STATUSES = %w[pending in_progress completed cancelled].freeze

  belongs_to :organization
  belongs_to :branch
  belongs_to :sales_order
  belongs_to :picker, class_name: 'User', optional: true

  has_many :pick_list_items, dependent: :destroy

  validates :status,      inclusion: { in: STATUSES }
  validates :pick_number, presence: true, uniqueness: { scope: :organization_id }

  before_validation :assign_pick_number, on: :create

  scope :pending,     -> { where(status: 'pending') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :completed,   -> { where(status: 'completed') }
  scope :by_branch,   ->(id) { where(branch_id: id) }
  scope :by_status,   ->(s)  { where(status: s) if s.present? }

  def pending?;     status == 'pending' end
  def in_progress?; status == 'in_progress' end
  def completed?;   status == 'completed' end

  def total_items;   pick_list_items.sum(:qty_requested) end
  def picked_items;  pick_list_items.sum(:qty_picked) end
  def all_picked?;   pick_list_items.all? { |i| i.qty_picked >= i.qty_requested } end

  def start!(user)
    raise "Already started" unless pending?
    update!(status: 'in_progress', picker: user, started_at: Time.current)
  end

  def complete!
    raise "Not all items picked" unless all_picked?
    update!(status: 'completed', completed_at: Time.current)
  end

  private

  def assign_pick_number
    return if pick_number.present?
    date_part = Date.current.strftime('%y%m%d')
    last      = PickList.where(organization_id: organization_id).where("pick_number LIKE ?", "PL-#{date_part}-%").count
    self.pick_number = "PL-#{date_part}-#{format('%04d', last + 1)}"
  end
end
