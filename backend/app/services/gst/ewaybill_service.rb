# frozen_string_literal: true

module Gst
  # Generates an e-waybill via the NIC E-Way Bill API.
  #
  # Usage:
  #   result = Gst::EwaybillService.generate(
  #     sales_invoice: invoice,
  #     transport_mode: 'road',
  #     vehicle_number: 'KA01AB1234',
  #     distance_km: 150
  #   )
  #
  class EwaybillService
    BASE_URL = ENV.fetch('GST_EWAYBILL_BASE_URL', 'https://gsp.adaequare.com/test').freeze

    Result = Struct.new(:success?, :ewaybill_request, :errors, keyword_init: true)

    def self.generate(**kwargs)
      new(**kwargs).generate
    end

    def self.cancel(ewaybill_request:, reason:)
      new(ewaybill_request: ewaybill_request).cancel(reason)
    end

    def initialize(sales_invoice: nil, transport_mode: 'road', vehicle_number: nil,
                   distance_km: nil, transporter_id: nil, transporter_name: nil,
                   ewaybill_request: nil)
      @sales_invoice    = sales_invoice
      @transport_mode   = transport_mode
      @vehicle_number   = vehicle_number
      @distance_km      = distance_km
      @transporter_id   = transporter_id
      @transporter_name = transporter_name
      @ewaybill_request = ewaybill_request
    end

    def generate
      invoice = @sales_invoice
      return Result.new(success?: false, errors: ['Sales invoice is required']) unless invoice

      # Check if e-waybill is required (typically for invoices > ₹50,000)
      threshold = BigDecimal(ENV.fetch('EWAYBILL_THRESHOLD', '50000'))
      if invoice.grand_total.to_d < threshold
        return Result.new(success?: false, errors: ["Invoice value #{invoice.grand_total} below e-waybill threshold #{threshold}"])
      end

      # Build or find existing request
      ewb = @ewaybill_request || EwaybillRequest.new(
        organization:   invoice.organization,
        sales_invoice:  invoice,
        requestable:    invoice,
        transport_mode: @transport_mode,
        vehicle_number: @vehicle_number,
        distance_km:    @distance_km,
        transporter_id: @transporter_id,
        transporter_name: @transporter_name
      )

      # Resolve addresses
      branch   = invoice.branch
      customer = invoice.customer
      billing  = customer.respond_to?(:addresses) ?
                   (customer.addresses.find { |a| a.label == 'billing' } || customer.addresses.first) :
                   nil

      ewb.from_state  = branch.state
      ewb.from_pincode = branch.pincode
      ewb.to_state    = billing&.state || customer.try(:state)
      ewb.to_pincode  = billing&.postal_code || customer.try(:pincode)

      payload = build_payload(invoice, ewb)

      begin
        response = post_to_api('/ewayapi/dec/v01/ewbgenerate', payload)

        if response[:success]
          ewb.mark_generated!(
            ewaybill_number: response[:data]['ewbNo'].to_s,
            valid_from:      parse_datetime(response[:data]['validFrom']),
            valid_until:     parse_datetime(response[:data]['validUpto']),
            response_json:   response[:data]
          )
          Result.new(success?: true, ewaybill_request: ewb, errors: [])
        else
          ewb.mark_error!(response[:message])
          ewb.save! if ewb.new_record?
          Result.new(success?: false, ewaybill_request: ewb, errors: [response[:message]])
        end
      rescue StandardError => e
        ewb.mark_error!(e.message)
        ewb.save! if ewb.new_record?
        Result.new(success?: false, ewaybill_request: ewb, errors: [e.message])
      end
    end

    def cancel(reason)
      ewb = @ewaybill_request
      return Result.new(success?: false, errors: ['E-waybill request not found']) unless ewb
      return Result.new(success?: false, errors: ['E-waybill not in generated status']) unless ewb.generated?

      payload = {
        ewbNo:      ewb.ewaybill_number.to_i,
        cancelRsnCode: 1, # 1=Duplicate, 2=Data Entry Mistake, 3=Order Cancelled, 4=Others
        cancelRmrk:    reason.to_s.truncate(100)
      }

      begin
        response = post_to_api('/ewayapi/dec/v01/ewbcancel', payload)

        if response[:success]
          ewb.mark_cancelled!(reason: reason)
          Result.new(success?: true, ewaybill_request: ewb, errors: [])
        else
          Result.new(success?: false, ewaybill_request: ewb, errors: [response[:message]])
        end
      rescue StandardError => e
        Result.new(success?: false, ewaybill_request: ewb, errors: [e.message])
      end
    end

    private

    def build_payload(invoice, ewb)
      branch = invoice.branch
      customer = invoice.customer
      lines = invoice.respond_to?(:lines) ? invoice.lines : []

      {
        supplyType:    'O', # Outward
        subSupplyType: 1,   # Supply
        docType:       'INV',
        docNo:         invoice.invoice_number,
        docDate:       invoice.invoice_date.strftime('%d/%m/%Y'),
        fromGstin:     invoice.organization.gst_number,
        fromTrdName:   invoice.organization.name,
        fromAddr1:     branch.address.to_s.truncate(120),
        fromPlace:     branch.city,
        fromPincode:   ewb.from_pincode.to_i,
        fromStateCode: branch.state_code.to_i,
        toGstin:       customer.gstin.presence || 'URP',
        toTrdName:     customer.name,
        toAddr1:       ewb.to_pincode.to_s, # simplified
        toPlace:       ewb.to_state,
        toPincode:     ewb.to_pincode.to_i,
        toStateCode:   customer.gstin.present? ? customer.gstin[0..1].to_i : branch.state_code.to_i,
        totalValue:    invoice.subtotal.to_f,
        cgstValue:     lines.sum { |l| l.try(:cgst_amount).to_f },
        sgstValue:     lines.sum { |l| l.try(:sgst_amount).to_f },
        igstValue:     lines.sum { |l| l.try(:igst_amount).to_f },
        cessValue:     lines.sum { |l| l.try(:cess_amount).to_f },
        totInvValue:   invoice.grand_total.to_f,
        transporterId: ewb.transporter_id,
        transporterName: ewb.transporter_name,
        transMode:     transport_mode_code(ewb.transport_mode),
        transDistance: (ewb.distance_km || 0).to_i,
        vehicleNo:     ewb.vehicle_number,
        vehicleType:   'R', # Regular
        itemList:      build_item_list(lines)
      }
    end

    def build_item_list(lines)
      lines.map do |line|
        {
          productName: line.product&.name.to_s.truncate(100),
          productDesc: line.product&.name.to_s.truncate(100),
          hsnCode:     line.try(:hsn_code) || line.product&.hsn_code,
          quantity:    line.qty.to_f,
          qtyUnit:     line.product&.units_of_measure&.symbol || 'NOS',
          taxableAmount: line.taxable_value.to_f,
          cgstRate:    line.try(:cgst_rate).to_f,
          sgstRate:    line.try(:sgst_rate).to_f,
          igstRate:    line.try(:igst_rate).to_f,
          cessRate:    line.try(:cess_rate).to_f
        }
      end
    end

    def transport_mode_code(mode)
      { 'road' => '1', 'rail' => '2', 'air' => '3', 'ship' => '4' }[mode] || '1'
    end

    def post_to_api(path, payload)
      # In production, this calls the actual NIC/GSP e-waybill API.
      # Requires authentication via GSTIN + API credentials.
      uri = URI("#{BASE_URL}#{path}")

      Rails.logger.info("[EwaybillService] POST #{uri} — #{payload[:docNo]}")

      if Rails.env.test? || Rails.env.development?
        # Mock response for dev/test
        return {
          success: true,
          data: {
            'ewbNo'     => SecureRandom.random_number(10**12).to_s,
            'validFrom' => Time.current.strftime('%d/%m/%Y %I:%M:%S %p'),
            'validUpto' => 1.day.from_now.strftime('%d/%m/%Y %I:%M:%S %p'),
            'ewbDt'     => Time.current.strftime('%d/%m/%Y %I:%M:%S %p')
          },
          message: 'E-waybill generated successfully (sandbox)'
        }
      end

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request = Net::HTTP::Post.new(uri.path, {
        'Content-Type' => 'application/json',
        'ewbauth'      => auth_token
      })
      request.body = payload.to_json

      response = http.request(request)
      body = JSON.parse(response.body)

      if response.code.to_i == 200 && body['success'].to_i == 1
        { success: true, data: body['result'], message: 'success' }
      else
        { success: false, data: nil, message: body['message'] || "API error: #{response.code}" }
      end
    end

    def auth_token
      # Cache auth token - production implementation would call /authenticate
      ENV.fetch('GST_EWAYBILL_AUTH_TOKEN', 'sandbox-token')
    end

    def parse_datetime(str)
      return nil unless str.present?
      DateTime.strptime(str, '%d/%m/%Y %I:%M:%S %p') rescue Time.current
    end
  end
end
