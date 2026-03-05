module Visits
  class CheckoutService
    Result = Struct.new(:success?, :visit_log, :errors)

    def initialize(visit_log:, params:, actor:)
      @visit_log = visit_log
      @params    = params.is_a?(ActionController::Parameters) ? params.to_h.symbolize_keys : params
      @actor     = actor
    end

    def call
      unless %w[checked_in planned].include?(@visit_log.visit_status)
        return Result.new(false, nil, ['Visit is already completed or skipped'])
      end

      ActiveRecord::Base.transaction do
        checkout_at = @params[:checkout_at]&.then { |t| Time.zone.parse(t.to_s) } || Time.current

        @visit_log.update!(
          checkout_at:  checkout_at,
          visit_status: 'completed',
          notes:        @params[:notes] || @visit_log.notes,
          gps_lat:      @params[:gps_lat] || @visit_log.gps_lat,
          gps_lng:      @params[:gps_lng] || @visit_log.gps_lng
        )

        # Update customer visit tracking
        @visit_log.customer.record_visit!(checkout_at)

        AuditLog.create!(
          actor:        @actor,
          organization: @visit_log.organization,
          auditable:    @visit_log,
          action:       'visit_checked_out',
          changes:      {
            customer_id:     @visit_log.customer_id,
            checkout_at:     @visit_log.checkout_at,
            duration_minutes: @visit_log.duration_minutes
          }
        )
      end

      Result.new(true, @visit_log, [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, nil, [e.message])
    end
  end
end
