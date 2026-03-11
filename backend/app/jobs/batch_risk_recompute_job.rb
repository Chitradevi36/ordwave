# frozen_string_literal: true
#
# Scheduled job: refreshes risk snapshots for all active retailers with
# a credit account.  Runs nightly (see config/sidekiq.yml).
#
# Can also be triggered on-demand:
#   BatchRiskRecomputeJob.perform_later(organization_id: org.id)
#
class BatchRiskRecomputeJob < ApplicationJob
  queue_as :low

  def perform(organization_id: nil)
    scope = Customer.not_deleted.joins(:credit_account).distinct
    scope = scope.where(organization_id: organization_id) if organization_id.present?

    processed = 0
    errors    = 0

    scope.find_each do |customer|
      Credit::RetailerRiskEngine.compute_and_save!(customer)
      processed += 1
    rescue StandardError => e
      errors += 1
      Rails.logger.error("[BatchRiskRecomputeJob] customer_id=#{customer.id} error=#{e.message}")
    end

    Rails.logger.info("[BatchRiskRecomputeJob] processed=#{processed} errors=#{errors}")
  end
end
