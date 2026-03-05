module Beats
  # Bulk-replaces the retailers for a BeatSchedule.
  # `retailers_params` is an array of hashes:
  #   [{ customer_id:, sequence_number:, visit_override:, notes: }, ...]
  class UpsertBeatRetailersService
    Result = Struct.new(:success?, :retailers, :errors)

    def initialize(schedule:, retailers_params:, actor:)
      @schedule         = schedule
      @retailers_params = retailers_params
      @actor            = actor
    end

    def call
      ActiveRecord::Base.transaction do
        existing     = @schedule.beat_retailers.index_by(&:customer_id)
        updated_ids  = []

        retailers = @retailers_params.map.with_index do |p, idx|
          p = p.is_a?(ActionController::Parameters) ? p.to_h.symbolize_keys : p
          cid = p[:customer_id].to_i

          br = existing[cid] || @schedule.beat_retailers.build(customer_id: cid)
          br.sequence_number = p.fetch(:sequence_number, idx)
          br.visit_override  = p.fetch(:visit_override, 'default')
          br.notes           = p[:notes]
          br.save!
          updated_ids << br.id
          br
        end

        # Remove any that were not in the new list
        @schedule.beat_retailers.where.not(id: updated_ids).destroy_all

        # Auto-sync: backfill sales_rep + visit_frequency on customers that lack them
        sync_customers!(retailers)

        AuditLog.create!(
          actor:        @actor,
          organization: @schedule.organization,
          auditable:    @schedule,
          action:       'beat_retailers_updated',
          changes:      { retailer_count: retailers.size }
        )

        Result.new(true, retailers, [])
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, [], [e.message])
    end

    private

    # For every customer now on this schedule:
    # - set sales_rep_id  if the customer has none
    # - set visit_frequency to 'weekly' if the customer has none
    # (never overwrites an explicitly-assigned value)
    def sync_customers!(retailers)
      customer_ids = retailers.map(&:customer_id)
      return if customer_ids.empty?

      rep_id = @schedule.sales_rep_id

      Customer.where(id: customer_ids, sales_rep_id: nil).update_all(sales_rep_id: rep_id) if rep_id
      Customer.where(id: customer_ids, visit_frequency: nil).update_all(visit_frequency: 'weekly')
    end
  end
end
