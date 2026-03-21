module Delivery
  # Completes a trip stop (marks as delivered/partial_delivery/failed).
  # Handles proof of delivery, per-line delivered quantities, return records,
  # and automatically marks the order status accordingly.
  #
  # Usage:
  #   result = Delivery::CompleteStopService.call(
  #     actor:            current_user,
  #     stop:             trip_stop,
  #     idempotency_key:  "uuid",
  #     outcome:          "delivered" | "partial_delivery" | "failed",
  #     delivered_lines:  [{ sales_order_line_id: 1, delivered_qty: 5 }, ...],
  #     returns:          [{ product_id: 1, qty_returned: 2, condition: "good", reason_code: "refused" }],
  #     proof_type:       "photo" | "signature" | "otp" | "override",
  #     photo:            uploaded_file,        # for photo proof
  #     signature_image:  uploaded_file,        # for signature proof
  #     otp_code:         "1234",               # for otp proof
  #     override_reason:  "unreachable area",   # for override proof
  #     latitude:         12.9716,
  #     longitude:        77.5946,
  #     device_id:        "device-uuid",
  #     exception_code:   nil,                  # if outcome is failed
  #     delivery_notes:   "Left with neighbour"
  #   )
  #
  class CompleteStopService
    VALID_OUTCOMES = %w[delivered partial_delivery failed].freeze

    def self.call(**kwargs)
      new(**kwargs).call
    end

    # `rejections` is an alias for `returns` (mobile-friendly naming)
    # `completed_at` is the device-local timestamp for offline-first audit trails
    # `proof` compact hash: { type: 'photo'|'signature'|'otp'|'override', data: base64_or_digest }
    def initialize(actor:, stop:, idempotency_key:, outcome:,
                   delivered_lines: [], returns: [], rejections: nil,
                   proof_type: 'photo', proof: nil,
                   photo: nil, signature_image: nil, otp_code: nil,
                   override_reason: nil, latitude: nil, longitude: nil,
                   device_id: nil, exception_code: nil, delivery_notes: nil,
                   completed_at: nil)
      @actor           = actor
      @stop            = stop
      @idempotency_key = idempotency_key
      @outcome         = outcome
      @delivered_lines = Array(delivered_lines)
      # Accept either `rejections:` or `returns:` (mobile sends rejections)
      @returns         = Array(rejections.presence || returns)
      # Accept compact `proof: { type:, data: }` hash OR individual params
      if proof.present?
        @proof_type      = proof[:type].presence || proof_type
        data             = proof[:data]
        case @proof_type
        when 'photo'     then @photo           = data
        when 'signature' then @signature_image = data
        when 'otp'       then @otp_code        = data
        when 'override'  then @override_reason = data
        end
      else
        @proof_type      = proof_type
        @photo           = photo
        @signature_image = signature_image
        @otp_code        = otp_code
        @override_reason = override_reason
      end
      @latitude        = latitude
      @longitude       = longitude
      @device_id       = device_id
      @exception_code  = exception_code
      @delivery_notes  = delivery_notes
      @completed_at    = completed_at
    end

    def call
      # Idempotency guard — already completed with same key
      if @idempotency_key.present? && @stop.idempotency_key == @idempotency_key && @stop.completed?
        return { ok: true, stop: @stop, errors: [] }
      end

      errors = validate
      return { ok: false, stop: @stop, errors: errors } if errors.any?

      # Gate check: Enforce geofence validation BEFORE marking delivered
      # If geofence enforcement enabled and delivery is far from address, require supervisor override
      if FEATURES.geofence_validation_enabled?(@actor&.organization) &&
         @latitude.present? && @longitude.present? &&
         @outcome.in?(%w[delivered partial_delivery])
        geofence_error = check_geofence_requirements
        return { ok: false, stop: @stop, errors: [geofence_error] } if geofence_error.present?
      end

      ActiveRecord::Base.transaction do
        # 1. Update stop
        # `completed_at` from device is used for audit-trail accuracy (offline submissions)
        delivery_timestamp = @completed_at.present? ? Time.zone.parse(@completed_at.to_s) : Time.current
        @stop.update!(
          status:          @outcome,
          delivered_at:    delivery_timestamp,
          latitude:        @latitude,
          longitude:       @longitude,
          device_id:       @device_id,
          exception_code:  @exception_code,
          delivery_notes:  @delivery_notes,
          idempotency_key: @idempotency_key
        )

        # 1a. Record geofence validation result for audit trail
        if @latitude.present? && @longitude.present? && @outcome.in?(%w[delivered partial_delivery])
          record_geofence_validation
        end

        proof = DeliveryProof.new(trip_stop: @stop, proof_type: @proof_type)
        proof.override_reason = @override_reason if @proof_type == 'override'
        proof.overridden_by   = @actor           if @proof_type == 'override'
        if @proof_type == 'otp' && @otp_code.present?
          proof.otp_code_digest = DeliveryProof.digest_otp(@otp_code)
          proof.otp_verified_at = Time.current
        end
        proof.photo           = @photo           if @photo.present?
        proof.signature_image = @signature_image if @signature_image.present?
        proof.save!

        # 3. Update per-line delivered qty
        @delivered_lines.each do |line_data|
          line = @stop.sales_order.lines.find(line_data[:sales_order_line_id])
          line.update!(delivered_qty: line_data[:delivered_qty].to_i)
        end

        # 4. Update returned_qty on matching order lines.
        # ReturnRecord writes are intentionally removed — ReturnRequest is the
        # authoritative record and is created post-commit by AutoCreateReturnService.
        # Writing to the deprecated return_records table caused dual-write inconsistency.
        @returns.each do |ret|
          line = @stop.sales_order.lines.find_by(product_id: ret[:product_id])
          line&.update!(returned_qty: (line.returned_qty || 0) + ret[:qty_returned].to_i)
        end

        # 5. Transition order status
        order = @stop.sales_order.reload
        if @outcome.in?(%w[delivered partial_delivery])
          order.transition_to!(@outcome)
          action = @outcome == 'delivered' ? 'order_delivered' : 'order_partial_delivery'
          Credit::AuditLogger.log(
            actor:        @actor,
            organization: @stop.delivery_trip.organization,
            auditable:    order,
            action:       action,
            changes:      { status: @outcome }
          )
        elsif @outcome == 'failed' && order.dispatched?
          # Revert to approved so the order can be re-routed on a new trip.
          # dispatched → approved is not in TRANSITIONS (no forward path), so
          # we bypass transition_to! intentionally — same pattern as CancelTripService.
          order.update!(status: 'approved', dispatched_at: nil)
          Credit::AuditLogger.log(
            actor:        @actor,
            organization: @stop.delivery_trip.organization,
            auditable:    order,
            action:       'order_delivery_failed',
            changes:      { status: 'approved', reverted_reason: 'delivery_failed',
                            exception_code: @exception_code }
          )
        end

        # 6. Check if whole trip is complete
        check_and_complete_trip!

        Credit::AuditLogger.log(
          actor:        @actor,
          organization: @stop.delivery_trip.organization,
          auditable:    @stop,
          action:       @exception_code.present? ? 'stop_exception_flagged' : 'stop_completed',
          changes:      { outcome: @outcome, stop_sequence: @stop.sequence }
        )

        { ok: true, stop: @stop.reload, errors: [] }
      end.tap do |result|
        if result[:ok]
          # Auto-invoice trigger: enqueue asynchronously after transaction commits
          Invoice::GenerateFromDeliveryJob.perform_later(@stop.id) if auto_invoice_enabled?

          # B4.2: Auto-create ReturnRequest from delivery rejections (partial delivery)
          if @outcome == 'partial_delivery' && @returns.any?
            Delivery::AutoCreateReturnService.call(stop: @stop.reload, actor: @actor)
          end

          # Auto-reschedule failed deliveries
          if @outcome == 'failed'
            Delivery::FailedDeliveryRescheduleService.call(
              trip_stop: @stop.reload,
              exception_code: @exception_code,
              notes: @delivery_notes,
              auto_reschedule: true,
              actor: @actor
            )
          end

          notify_on_stop_completion
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      { ok: false, stop: @stop, errors: [e.message] }
    end

    private

    def notify_on_stop_completion
      org   = @stop.delivery_trip.organization
      order = @stop.sales_order

      if @outcome.in?(%w[delivered partial_delivery])
        recipients = [order.created_by].compact
        Notifications::CreateService.call(
          organization: org,
          recipients:   recipients,
          actor:        @actor,
          notifiable:   @stop,
          type:         'delivery_completed',
          title:        "Order #{order.order_number} #{@outcome == 'delivered' ? 'delivered' : 'partially delivered'}",
          body:         "Delivery confirmed for #{order.customer&.name}.",
          deep_link:    "/orders/#{order.id}",
          severity:     'medium'
        )
      elsif @outcome == 'failed'
        managers = User.joins(:memberships)
                       .where(memberships: { organization_id: org.id, deleted_at: nil, active: true })
                       .joins(memberships: :role)
                       .where(roles: { name: %w[manager admin] })
                       .distinct
        recipients = ([order.created_by] + managers.to_a).compact.uniq
        Notifications::CreateService.call(
          organization: org,
          recipients:   recipients,
          actor:        @actor,
          notifiable:   @stop,
          type:         'delivery_failed',
          title:        "Delivery failed — Order #{order.order_number}",
          body:         "Exception: #{@exception_code}. #{@delivery_notes}".strip,
          deep_link:    "/orders/#{order.id}",
          severity:     'high'
        )
      end
    rescue StandardError => e
      Rails.logger.warn("[CompleteStopService] Notification failed: #{e.message}")
    end

    def validate
      errs = []
      errs << 'Outcome is required' if @outcome.blank?
      errs << "Invalid outcome '#{@outcome}'" unless @outcome.in?(VALID_OUTCOMES)
      errs << 'Stop is already completed' if @stop.completed?
      errs << 'Trip must be dispatched' unless @stop.delivery_trip.dispatched?

      if @outcome == 'failed' && @exception_code.blank?
        errs << 'Exception code is required when outcome is failed'
      end
      if @proof_type == 'override' && @override_reason.blank?
        errs << 'Override reason is required'
      end
      errs
    end

    def auto_invoice_enabled?
      return false unless @outcome.in?(%w[delivered partial_delivery])
      org     = @stop.delivery_trip.organization
      
      # Check global feature flag first
      return false unless FEATURES.auto_invoice_enabled?(org)
      
      # Read trigger from CreditPolicy (single source of truth);
      # fall back to org.settings for backward compatibility.
      policy  = org.credit_policy
      trigger = policy&.auto_invoice_trigger.to_s
      trigger = org.settings&.dig('auto_invoice_trigger').to_s if trigger.blank?
      trigger.blank? || trigger == 'on_delivery'
    end

    def check_geofence_requirements
      # Gate check: Called BEFORE marking delivery complete
      # Returns error message if geofence violation detected without override
      
      geofence_result = Delivery::GeofenceValidationService.call(
        trip_stop: @stop,
        latitude: @latitude,
        longitude: @longitude
      )

      case geofence_result.status
      when 'outside_geofence'
        distance_m = geofence_result.distance_m

        # Hard block: > 1000m away (clearly wrong address or fraud attempt)
        if distance_m > 1000
          return "Delivery location is #{distance_m.round(0)}m away from customer address. " \
                 "This looks like the wrong address. Cannot mark delivered."
        end

        # Soft block: > 500m away (requires supervisor override code)
        if distance_m > 500
          # Override code not provided OR override timeout expired
          unless @override_reason.present? && within_override_timeout?
            return "Delivery location is #{distance_m.round(0)}m away from customer address. " \
                   "Supervisor approval required. Contact your manager for override code."
          end

          # Log override for audit trail
          log_geofence_override(distance_m)
        end

        # Within 500m is acceptable but log for monitoring
        nil
      else
        # Within geofence - no error
        nil
      end
    rescue => error
      Rails.logger.warn("Geofence check failed: #{error.message}")
      nil # Don't block delivery if geofence service fails
    end

    def within_override_timeout?
      # Override code valid for 5 minutes after issue
      # In production, could validate against manager-issued one-time codes
      # For now, just checking presence indicates supervisor approved
      true
    end

    def log_geofence_override(distance_m)
      org = @stop.delivery_trip.organization
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: org,
        auditable:    @stop,
        action:       'geofence_override_approved',
        changes:      {
          distance_m: distance_m.round(1),
          latitude: @latitude,
          longitude: @longitude
        },
        reason: "Delivery #{distance_m.round(0)}m away, supervisor override: #{@override_reason}"
      )

      # Notify ops manager about override
      Notification.create(
        user_id: org.users.where(role: %w[owner admin manager]).first&.id,
        organization_id: org.id,
        title: 'Geofence Override Approved',
        body: "Driver #{@actor.name} completed delivery #{distance_m.round(0)}m from address (Override: #{@override_reason})",
        notification_type: 'geofence_override',
        deep_link_url: "/trips/#{@stop.delivery_trip.id}"
      ) if org.users.where(role: %w[owner admin manager]).exists?
    end

    def record_geofence_validation
      # Record geofence data for audit trail (called AFTER delivery marked complete)
      geofence_result = Delivery::GeofenceValidationService.call(
        trip_stop: @stop,
        latitude: @latitude,
        longitude: @longitude
      )

      # Record geofence validation result
      @stop.update(
        geofence_status: geofence_result.status,
        geofence_distance_m: geofence_result.distance_m,
        geofence_validated_at: Time.current
      )

      # Log if outside geofence (for monitoring)
      if geofence_result.status == 'outside_geofence'
        org = @stop.delivery_trip.organization
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: org,
          auditable:    @stop,
          action:       'delivery_outside_geofence_recorded',
          changes:      {
            geofence_status: 'outside_geofence',
            distance_m: geofence_result.distance_m.round(1),
            latitude: @latitude,
            longitude: @longitude
          },
          reason: "Delivery completed #{geofence_result.distance_m.round(1)}m from customer address"
        )
      end
    rescue => error
      Rails.logger.warn({
        service: 'Delivery::CompleteStopService',
        action: 'record_geofence_validation',
        stop_id: @stop.id,
        error: error.message
      }.to_json)
      # Don't fail the delivery - recording is informational
    end

    def validate_geofence
      # DEPRECATED - use check_geofence_requirements + record_geofence_validation instead
      # Kept for backwards compatibility
      geofence_result = Delivery::GeofenceValidationService.call(
        trip_stop: @stop,
        latitude: @latitude,
        longitude: @longitude
      )

      # Record geofence validation result
      @stop.update(
        geofence_status: geofence_result.status,
        geofence_distance_m: geofence_result.distance_m,
        geofence_validated_at: Time.current
      )

      # Log if outside geofence (potential anomaly)
      if geofence_result.status == 'outside_geofence'
        org = @stop.delivery_trip.organization
        Credit::AuditLogger.log(
          actor:        @actor,
          organization: org,
          auditable:    @stop,
          action:       'delivery_outside_geofence',
          changes:      {
            geofence_status: 'outside_geofence',
            distance_m: geofence_result.distance_m.round(1),
            latitude: @latitude,
            longitude: @longitude
          },
          reason: "Delivery marked #{@distance_m.round(1)}m away from customer address"
        )

        # Alert admins if significantly outside geofence
        if geofence_result.distance_m > 500  # More than 500m away
          Notification.create(
            user_id: @stop.delivery_trip.driver_id,
            organization_id: org.id,
            title: 'Geofence Anomaly Detected',
            body: "Delivery location #{geofence_result.distance_m.round(1)}m from customers address.",
            notification_type: 'geofence_anomaly',
            deep_link_url: "/trips/#{@stop.delivery_trip.id}"
          )
        end
      end
    rescue => error
      Rails.logger.warn({
        service: 'Delivery::CompleteStopService',
        action: 'validate_geofence',
        stop_id: @stop.id,
        error: error.message
      }.to_json)
      # Don't fail the delivery - geofence is informational
    end

    def check_and_complete_trip!
      # Use a row-level lock to prevent race condition when two drivers complete
      # their final stops concurrently — only one transaction will win the lock
      # and perform the transition; the other will see trip already completed.
      trip = @stop.delivery_trip.lock!.reload
      return if trip.completed?

      all_complete = trip.stops.not_deleted.all?(&:completed?)
      return unless all_complete

      trip.transition_to!('completed')
      Credit::AuditLogger.log(
        actor:        @actor,
        organization: trip.organization,
        auditable:    trip,
        action:       'trip_completed',
        changes:      { status: 'completed', completed_at: trip.completed_at }
      )
    end
  end
end
