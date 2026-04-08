require "net/http"
require "json"

module Gst
  # Generates a GST e-invoice (IRN) by pushing invoice data to the NIC IRP
  # (Invoice Registration Portal) sandbox or production API.
  #
  # Credentials are read from ENV:
  #   GST_IRP_BASE_URL  — e.g. "https://einv-apisandbox.nic.in" (sandbox)
  #   GST_CLIENT_ID     — issued by NIC after registration
  #   GST_CLIENT_SECRET
  #   GST_GSTIN         — seller's GSTIN
  #   GST_USERNAME
  #   GST_PASSWORD
  #
  # Usage:
  #   result = Gst::EinvoiceService.call(invoice: sales_invoice)
  #   result.success?    # => true / false
  #   result.irn         # => "abc123..."
  #   result.ack_number  # => "12345678"
  #   result.qr_code     # => base64 QR string
  #   result.errors      # => []
  #
  class EinvoiceService
    EINVOICE_STATUSES = %w[not_required pending generated failed].freeze

    Result = Struct.new(:success?, :irn, :ack_number, :ack_datetime, :qr_code, :errors)

    BASE_URL      = ENV.fetch("GST_IRP_BASE_URL", "https://einv-apisandbox.nic.in")
    CLIENT_ID     = ENV.fetch("GST_CLIENT_ID",     "")
    CLIENT_SECRET = ENV.fetch("GST_CLIENT_SECRET", "")
    GSTIN         = ENV.fetch("GST_GSTIN",         "")
    GST_USERNAME  = ENV.fetch("GST_USERNAME",      "")
    GST_PASSWORD  = ENV.fetch("GST_PASSWORD",      "")

    def self.call(invoice:)
      new(invoice: invoice).call
    end

    def initialize(invoice:)
      @invoice = invoice
    end

    def call
      validate_prerequisites!

      token   = fetch_auth_token
      payload = build_einvoice_payload

      response = post_einvoice(token, payload)

      handle_response(response)
    rescue EinvoiceError => e
      @invoice.update_columns(einvoice_status: "failed", einvoice_error: e.message)
      Result.new(false, nil, nil, nil, nil, [e.message])
    rescue => e
      Sentry.capture_exception(e) if defined?(Sentry)
      @invoice.update_columns(einvoice_status: "failed", einvoice_error: e.message)
      Rails.logger.error("[Gst::EinvoiceService] Unexpected error: #{e.message}")
      Result.new(false, nil, nil, nil, nil, [e.message])
    end

    private

    # ── Prerequisites ────────────────────────────────────────────────────────
    def validate_prerequisites!
      raise EinvoiceError, "Invoice must be in 'issued' status" unless @invoice.issued?
      raise EinvoiceError, "IRN already generated for this invoice" if @invoice.irn.present?
      raise EinvoiceError, "GST credentials not configured" if CLIENT_ID.blank?
    end

    # ── Auth token ───────────────────────────────────────────────────────────
    def fetch_auth_token
      uri = URI("#{BASE_URL}/eivital/v1.04/auth")
      body = {
        UserName: GST_USERNAME,
        Password: GST_PASSWORD,
        AppKey:   CLIENT_SECRET,
        ForceRefreshAccessToken: false
      }.to_json

      res = post_json(uri, body, headers_base)
      raise EinvoiceError, "Auth failed: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

      JSON.parse(res.body).dig("Data", "AuthToken") ||
        raise(EinvoiceError, "Auth token not found in response")
    end

    # ── E-Invoice payload (NIC schema v1.1) ──────────────────────────────────
    def build_einvoice_payload
      inv  = @invoice
      org  = inv.organization
      branch = inv.branch
      cust = inv.customer

      # Use three-tier GSTIN lookup: branch override > state > org
      seller_gstin = branch.effective_gstin || GSTIN

      {
        Version: "1.1",
        TranDtls: { TaxSch: "GST", SupTyp: "B2B", RegRev: "N", EcmGstin: nil, IgstOnIntra: "N" },
        DocDtls: {
          Typ:  "INV",
          No:   inv.invoice_number,
          Dt:   inv.invoice_date.strftime("%d/%m/%Y")
        },
        SellerDtls: {
          Gstin:  seller_gstin,
          TrdNm:  org.name,
          Addr1:  org.address_line1,
          Addr2:  org.address_line2,
          Loc:    org.city,
          Pin:    org.pincode.to_i,
          Stcd:   org.state_code,
          Ph:     org.phone,
          Em:     org.email
        },
        BuyerDtls: {
          Gstin:  cust.gstin.presence || "URP",
          TrdNm:  cust.name,
          Pos:    cust.state_code || org.state_code,
          Addr1:  cust.address_line1,
          Addr2:  cust.address_line2,
          Loc:    cust.city,
          Pin:    cust.pincode.to_i,
          Stcd:   cust.state_code
        },
        ItemList: build_item_list(inv),
        ValDtls: {
          AssVal:  inv.subtotal.to_f,
          CgstVal: inv.gst_summary[:cgst_total].to_f,
          SgstVal: inv.gst_summary[:sgst_total].to_f,
          IgstVal: inv.gst_summary[:igst_total].to_f,
          TotInvVal: inv.grand_total.to_f
        },
        EwbDtls: nil
      }.to_json
    end

    def build_item_list(inv)
      inv.lines.map.with_index(1) do |line, idx|
        {
          SlNo:      idx.to_s,
          PrdDesc:   line.product.name,
          IsServc:   "N",
          HsnCd:     line.hsn_code,
          Qty:       line.quantity.to_f,
          Unit:      "NOS",
          UnitPrice: line.unit_price.to_f,
          TotAmt:    line.line_total.to_f,
          Discount:  line.discount_amount.to_f,
          AssAmt:    line.taxable_value.to_f,
          GstRt:     line.gst_rate.to_f,
          CgstAmt:   line.cgst_amount.to_f,
          SgstAmt:   line.sgst_amount.to_f,
          IgstAmt:   line.igst_amount.to_f,
          TotItemVal: line.total_amount.to_f
        }
      end
    end

    # ── IRP API call ─────────────────────────────────────────────────────────
    def post_einvoice(auth_token, payload)
      uri = URI("#{BASE_URL}/eicore/v1.03/Invoice")
      headers = headers_base.merge("AuthToken" => auth_token)
      post_json(uri, payload, headers)
    end

    def handle_response(response)
      raise EinvoiceError, "IRP API error #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      body = JSON.parse(response.body)
      data = body["Data"] || {}

      irn          = data["Irn"]
      ack_number   = data["AckNo"]
      ack_datetime = data["AckDt"]
      qr_code      = data["SignedQRCode"]

      raise EinvoiceError, "IRP returned no IRN: #{body}" if irn.blank?

      @invoice.update_columns(
        irn:                irn,
        ack_number:         ack_number,
        ack_datetime:        ack_datetime,
        einvoice_qr_code:   qr_code,
        einvoice_status:    "generated",
        irn_generated_at:   Time.current,
        einvoice_error:     nil
      )

      AuditLog.create!(
        organization: @invoice.organization,
        actor:        Current.user || @invoice.created_by,
        auditable:    @invoice,
        action:       "invoice_issued",
        changes_data: { irn: irn, ack_number: ack_number }
      )

      Rails.logger.info("[Gst::EinvoiceService] IRN generated for Invoice##{@invoice.id}: #{irn}")
      Result.new(true, irn, ack_number, ack_datetime, qr_code, [])
    end

    # ── HTTP helpers ─────────────────────────────────────────────────────────
    def headers_base
      {
        "Content-Type" => "application/json",
        "client_id"    => CLIENT_ID,
        "client_secret" => CLIENT_SECRET,
        "gstin"        => GSTIN
      }
    end

    def post_json(uri, body, headers)
      http              = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 15

      request = Net::HTTP::Post.new(uri.path)
      headers.each { |k, v| request[k] = v }
      request.body = body

      http.request(request)
    end

    class EinvoiceError < StandardError; end
  end
end
