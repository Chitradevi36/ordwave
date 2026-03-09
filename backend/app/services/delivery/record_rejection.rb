# frozen_string_literal: true

module Delivery
  # Handles at-door rejection during delivery.
  # When a delivery driver reports that a customer rejected some items,
  # this service:
  #   1. Records the rejection against the trip stop
  #   2. Optionally auto-creates a ReturnRequest in submitted state
  #   3. Updates the trip stop status to partial_delivery (if some items accepted)
  #   4. Updates sales_order_line delivered/returned quantities
  #
  # Usage:
  #   result = Delivery::RecordRejection.call(
  #     actor: driver_user,
  #     trip_stop: stop,
  #     rejections: [
  #       { product_id: 1, qty_rejected: 5, reason_code: 'quality_issue', condition: 'damaged' },
  #       { product_id: 2, qty_rejected: 3, reason_code: 'expired', condition: 'unopened' }
  #     ]
  #   )
  #
  class RecordRejection
    Result = Struct.new(:success?, :trip_stop, :rejections, :return_request, :errors)

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(actor:, trip_stop:, rejections:, auto_return: true)
      @actor       = actor
      @trip_stop   = trip_stop
      @rejections  = Array(rejections)
      @auto_return = auto_return
    end

    def call
      validate!

      created_rejections = []
      return_request = nil

      ActiveRecord::Base.transaction do
        @rejections.each do |rej_attrs|
          attrs = rej_attrs.is_a?(ActionController::Parameters) ?
                    rej_attrs.to_h.deep_symbolize_keys : rej_attrs.symbolize_keys

          rejection = DeliveryRejection.create!(
            trip_stop:   @trip_stop,
            sales_order: @trip_stop.sales_order,
            product_id:  attrs[:product_id],
            rejected_by: @actor,
            qty_rejected: attrs[:qty_rejected].to_d,
            reason_code: attrs[:reason_code] || 'other',
            condition:   attrs[:condition] || 'unopened',
            notes:       attrs[:notes],
            auto_return: @auto_return
          )

          created_rejections << rejection

          # Update sales order line returned qty
          update_order_line_returned_qty(attrs[:product_id], attrs[:qty_rejected].to_d)
        end

        # Update trip stop status
        update_trip_stop_status

        # Auto-create return request if enabled
        if @auto_return && created_rejections.any?
          return_request = create_return_request(created_rejections)
          # Link rejections to the return request
          created_rejections.each { |r| r.update!(return_request_id: return_request.id) }
        end
      end

      Result.new(true, @trip_stop.reload, created_rejections, return_request, [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(false, @trip_stop, [], nil, [e.message])
    rescue StandardError => e
      Result.new(false, @trip_stop, [], nil, [e.message])
    end

    private

    def validate!
      unless @trip_stop.delivered? || @trip_stop.pending?
        raise "Trip stop must be in pending or delivered status (current: #{@trip_stop.status})"
      end

      raise "No rejections provided" if @rejections.blank?

      @rejections.each do |rej|
        rej = rej.symbolize_keys
        raise "Product ID required for each rejection" unless rej[:product_id]
        raise "Qty rejected must be > 0" unless rej[:qty_rejected].to_d.positive?
      end
    end

    def update_order_line_returned_qty(product_id, qty)
      order = @trip_stop.sales_order
      line = order.lines.find_by(product_id: product_id)
      return unless line

      new_returned = (line.returned_qty || 0).to_d + qty
      line.update!(returned_qty: new_returned)
    end

    def update_trip_stop_status
      order = @trip_stop.sales_order
      total_ordered = order.lines.sum(&:qty).to_d
      total_rejected = @rejections.sum { |r| r.is_a?(Hash) ? r[:qty_rejected].to_d : r.symbolize_keys[:qty_rejected].to_d }

      if total_rejected >= total_ordered
        @trip_stop.update!(status: 'failed', exception_code: 'refused_by_customer')
      else
        @trip_stop.update!(status: 'partial_delivery')
      end
    end

    def create_return_request(rejections)
      order   = @trip_stop.sales_order
      org     = order.organization
      branch  = order.branch
      customer = order.customer

      rr = ReturnRequest.create!(
        organization: org,
        branch:       branch,
        customer:     customer,
        created_by:   @actor,
        source_type:  'delivery',
        source_id:    @trip_stop.id,
        return_number: generate_return_number(org),
        return_date:  Date.current,
        status:       'submitted',
        submitted_at: Time.current,
        notes:        "Auto-created from delivery rejection at trip stop ##{@trip_stop.id}"
      )

      rejections.each do |rejection|
        product = Product.find(rejection.product_id)
        order_line = order.lines.find_by(product_id: rejection.product_id)

        rr.lines.create!(
          product:              product,
          sales_order_line:     order_line,
          qty_reported:         rejection.qty_rejected,
          condition_reported:   map_condition(rejection.condition),
          reason_code:          rejection.reason_code,
          unit_price_snapshot:  order_line&.unit_price,
          gst_rate_snapshot:    order_line&.gst_rate,
          hsn_code_snapshot:    order_line&.hsn_code || product.hsn_code
        )
      end

      rr
    end

    def generate_return_number(org)
      prefix = "RET"
      max = ReturnRequest.where(organization: org)
                         .where("return_number LIKE ?", "#{prefix}%")
                         .order(return_number: :desc)
                         .limit(1)
                         .pluck(:return_number)
                         .first

      seq = max ? max.gsub(/\D/, '').to_i + 1 : 1
      "#{prefix}#{seq.to_s.rjust(6, '0')}"
    end

    def map_condition(rejection_condition)
      case rejection_condition
      when 'damaged'  then 'damaged'
      when 'opened'   then 'opened'
      else 'unknown'
      end
    end
  end
end
