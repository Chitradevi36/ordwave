class GenerateCollectionSchedulesJob < ApplicationJob
  queue_as :default

  # Scheduled nightly via sidekiq-cron to auto-generate collection schedule entries
  # for overdue invoices. Assigns them to the customer's designated sales rep or
  # the branch's default collector.
  #
  # Sidekiq-cron entry (config/sidekiq.yml):
  #   generate_collection_schedules:
  #     cron: '0 20 * * *'   # 8 PM daily (next-day schedules)
  #     class: GenerateCollectionSchedulesJob
  #     args: []
  #
  def self.schedule_for_org(org_id)
    perform_later(org_id)
  end

  def perform(organization_id = nil)
    scope = organization_id.present? ?
            Organization.active.where(id: organization_id) :
            Organization.active

    scope.find_each { |org| generate_for_org(org) }
  end

  private

  def generate_for_org(org)
    # Find overdue issued invoices with outstanding balance
    overdue_invoices = SalesInvoice
      .for_org(org)
      .where(status: "issued")
      .where("due_date < ?", Date.current)
      .where("outstanding_amount > 0")
      .includes(:customer, :branch)

    return if overdue_invoices.empty?

    target_date = next_business_day

    overdue_invoices.each do |invoice|
      existing = CollectionSchedule
        .for_organization(org.id)
        .for_customer(invoice.customer_id)
        .for_date(target_date)
        .where(status: "planned")
        .first

      # Skip if a planned schedule already exists for this customer on target date
      next if existing.present?

      collector = find_collector(org, invoice)
      next unless collector

      CollectionSchedule.create!(
        organization:    org,
        branch:          invoice.branch,
        customer:        invoice.customer,
        assigned_to:     collector,
        scheduled_date:  target_date,
        amount_expected: invoice.outstanding_amount,
        notes:           "Auto-generated: #{invoice.invoice_number} overdue since #{invoice.due_date.strftime('%d %b %Y')}"
      )
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[GenerateCollectionSchedulesJob] Failed to create schedule for invoice #{invoice.id}: #{e.message}")
    end
  end

  # Returns next weekday (Mon-Fri) from today
  def next_business_day
    date = Date.current + 1
    date += 1 while date.saturday? || date.sunday?
    date
  end

  # Finds the best collector for an invoice:
  # 1. Customer's assigned sales rep
  # 2. Any member of the branch with role: sales_rep, member
  # 3. Branch manager
  def find_collector(org, invoice)
    # Check if customer has an assigned sales rep via memberships
    customer = invoice.customer
    assigned = customer.respond_to?(:assigned_user) ? customer.assigned_user : nil
    return assigned if assigned.present?

    # Fallback: first active sales_rep or member in the branch
    org.memberships
       .active
       .joins(:role, :user)
       .where(roles: { name: %w[member sales_rep] })
       .where.not(users: { id: nil })
       .order(:created_at)
       .first
       &.user
  end
end
