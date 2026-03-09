# frozen_string_literal: true

module Gst
  # Generates GSTR-1 return data for a given period.
  # GSTR-1 is the monthly/quarterly return for outward supplies.
  #
  # Produces structured data for:
  # - B2B invoices (to registered dealers with GSTIN)
  # - B2C Large (to unregistered persons, inter-state, > ₹2.5L)
  # - B2C Small (to unregistered persons, intra-state or inter-state < ₹2.5L)
  # - Credit/Debit Notes
  # - HSN Summary
  #
  # Usage:
  #   result = Gst::Gstr1ExportService.call(
  #     organization: org,
  #     period_from: Date.new(2026, 3, 1),
  #     period_to: Date.new(2026, 3, 31)
  #   )
  #   result.b2b_invoices   # => array of B2B invoice hashes
  #   result.hsn_summary    # => array of HSN summary hashes
  #
  class Gstr1ExportService
    B2C_LARGE_THRESHOLD = BigDecimal('250000')

    Result = Struct.new(
      :b2b_invoices, :b2c_large, :b2c_small,
      :credit_debit_notes, :hsn_summary,
      :document_summary, :period, :gstin,
      keyword_init: true
    )

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, period_from:, period_to:, branch_id: nil)
      @organization = organization
      @period_from  = period_from
      @period_to    = period_to
      @branch_id    = branch_id
    end

    def call
      invoices     = fetch_invoices
      credit_notes = fetch_credit_notes

      Result.new(
        b2b_invoices:       build_b2b(invoices),
        b2c_large:          build_b2c_large(invoices),
        b2c_small:          build_b2c_small(invoices),
        credit_debit_notes: build_cdnr(credit_notes),
        hsn_summary:        build_hsn_summary(invoices),
        document_summary:   build_doc_summary(invoices, credit_notes),
        period:             { from: @period_from, to: @period_to },
        gstin:              @organization.gst_number
      )
    end

    private

    def fetch_invoices
      scope = SalesInvoice
        .where(organization: @organization)
        .where(status: 'issued')
        .where(invoice_date: @period_from..@period_to)
        .includes(:customer, :branch, lines: :product)

      scope = scope.where(branch_id: @branch_id) if @branch_id
      scope.to_a
    end

    def fetch_credit_notes
      scope = CreditNote
        .where(organization: @organization)
        .where(status: 'issued')
        .where(issued_at: @period_from.beginning_of_day..@period_to.end_of_day)
        .includes(:customer, lines: :product)

      scope = scope.where(branch_id: @branch_id) if @branch_id
      scope.to_a
    end

    # ── B2B: Invoices to registered dealers (with GSTIN) ────────────────────────
    def build_b2b(invoices)
      b2b_invoices = invoices.select { |inv| inv.customer.gstin.present? }

      b2b_invoices.group_by { |inv| inv.customer.gstin }.map do |gstin, inv_group|
        {
          ctin: gstin,
          inv:  inv_group.map { |inv| format_b2b_invoice(inv) }
        }
      end
    end

    def format_b2b_invoice(inv)
      branch = inv.branch
      is_inter = inter_state?(branch, inv.customer)

      {
        inum:  inv.invoice_number,
        idt:   inv.invoice_date.strftime('%d-%m-%Y'),
        val:   inv.grand_total.to_f,
        pos:   place_of_supply_code(inv),
        rchrg: 'N',
        inv_typ: 'R', # Regular
        itms:  build_rate_items(inv.lines, is_inter)
      }
    end

    # ── B2C Large: Inter-state to unregistered, > ₹2.5L ────────────────────────
    def build_b2c_large(invoices)
      invoices
        .select { |inv| inv.customer.gstin.blank? && inv.grand_total.to_d >= B2C_LARGE_THRESHOLD && inter_state?(inv.branch, inv.customer) }
        .map do |inv|
          {
            pos:   place_of_supply_code(inv),
            inum:  inv.invoice_number,
            idt:   inv.invoice_date.strftime('%d-%m-%Y'),
            val:   inv.grand_total.to_f,
            itms:  build_rate_items(inv.lines, true)
          }
        end
    end

    # ── B2C Small: Intra-state or inter-state < ₹2.5L ──────────────────────────
    def build_b2c_small(invoices)
      b2cs = invoices.select { |inv| inv.customer.gstin.blank? && !in_b2c_large?(inv) }

      # Aggregate by state + rate
      aggregated = {}
      b2cs.each do |inv|
        is_inter = inter_state?(inv.branch, inv.customer)
        inv.lines.each do |line|
          key = "#{place_of_supply_code(inv)}_#{line.gst_rate}_#{is_inter ? 'I' : 'OE'}"
          aggregated[key] ||= {
            pos:    place_of_supply_code(inv),
            sply_ty: is_inter ? 'INTER' : 'INTRA',
            rt:     line.gst_rate.to_f,
            txval:  0.0,
            camt:   0.0,
            samt:   0.0,
            iamt:   0.0,
            csamt:  0.0
          }
          aggregated[key][:txval] += line.taxable_value.to_f
          aggregated[key][:camt]  += line.try(:cgst_amount).to_f
          aggregated[key][:samt]  += line.try(:sgst_amount).to_f
          aggregated[key][:iamt]  += line.try(:igst_amount).to_f
          aggregated[key][:csamt] += line.try(:cess_amount).to_f
        end
      end

      aggregated.values.map { |v| v.transform_values { |val| val.is_a?(Float) ? val.round(2) : val } }
    end

    # ── CDNR: Credit/Debit notes to registered dealers ─────────────────────────
    def build_cdnr(credit_notes)
      registered = credit_notes.select { |cn| cn.customer.gstin.present? }

      registered.group_by { |cn| cn.customer.gstin }.map do |gstin, notes|
        {
          ctin: gstin,
          nt:   notes.map do |cn|
            {
              ntty:  'C', # Credit Note
              nt_num: cn.credit_note_number,
              nt_dt:  cn.issued_at&.strftime('%d-%m-%Y'),
              val:    cn.total.to_f,
              itms:   cn.lines.group_by(&:gst_rate).map do |rate, lines|
                {
                  num: 1,
                  itm_det: {
                    rt:    rate.to_f,
                    txval: lines.sum(&:unit_price).to_f * lines.sum(&:qty).to_f, # simplified
                    camt:  (lines.sum { |l| l.tax_amount / 2 }).round(2).to_f,
                    samt:  (lines.sum { |l| l.tax_amount / 2 }).round(2).to_f,
                    iamt:  0.0,
                    csamt: 0.0
                  }
                }
              end
            }
          end
        }
      end
    end

    # ── HSN Summary ─────────────────────────────────────────────────────────────
    def build_hsn_summary(invoices)
      hsn_data = {}

      invoices.each do |inv|
        is_inter = inter_state?(inv.branch, inv.customer)
        inv.lines.each do |line|
          hsn = line.hsn_code || line.product&.hsn_code || 'UNKNOWN'
          uom = line.product&.units_of_measure&.symbol || 'NOS'
          key = "#{hsn}_#{line.gst_rate}"

          hsn_data[key] ||= {
            hsn_sc:  hsn,
            desc:    line.product&.name.to_s.truncate(30),
            uqc:     uom,
            qty:     0.0,
            rt:      line.gst_rate.to_f,
            txval:   0.0,
            camt:    0.0,
            samt:    0.0,
            iamt:    0.0,
            csamt:   0.0
          }

          hsn_data[key][:qty]   += line.qty.to_f
          hsn_data[key][:txval] += line.taxable_value.to_f
          if is_inter
            hsn_data[key][:iamt] += line.tax_amount.to_f
          else
            hsn_data[key][:camt] += (line.tax_amount.to_f / 2).round(2)
            hsn_data[key][:samt] += (line.tax_amount.to_f / 2).round(2)
          end
          hsn_data[key][:csamt] += line.try(:cess_amount).to_f
        end
      end

      hsn_data.values.map { |v| v.transform_values { |val| val.is_a?(Float) ? val.round(2) : val } }
    end

    # ── Document Summary ────────────────────────────────────────────────────────
    def build_doc_summary(invoices, credit_notes)
      {
        total_invoices:    invoices.size,
        total_credit_notes: credit_notes.size,
        b2b_count:         invoices.count { |inv| inv.customer.gstin.present? },
        b2c_count:         invoices.count { |inv| inv.customer.gstin.blank? },
        total_taxable:     invoices.sum { |inv| inv.subtotal.to_f }.round(2),
        total_tax:         invoices.sum { |inv| inv.tax_total.to_f }.round(2),
        total_invoice_value: invoices.sum { |inv| inv.grand_total.to_f }.round(2),
        total_cn_value:    credit_notes.sum { |cn| cn.total.to_f }.round(2)
      }
    end

    # ── Helpers ─────────────────────────────────────────────────────────────────

    def build_rate_items(lines, is_inter)
      lines.group_by(&:gst_rate).map do |rate, rate_lines|
        {
          num: 1,
          itm_det: {
            rt:    rate.to_f,
            txval: rate_lines.sum(&:taxable_value).to_f.round(2),
            camt:  is_inter ? 0.0 : rate_lines.sum { |l| l.try(:cgst_amount).to_f }.round(2),
            samt:  is_inter ? 0.0 : rate_lines.sum { |l| l.try(:sgst_amount).to_f }.round(2),
            iamt:  is_inter ? rate_lines.sum { |l| l.try(:igst_amount).to_f }.round(2) : 0.0,
            csamt: rate_lines.sum { |l| l.try(:cess_amount).to_f }.round(2)
          }
        }
      end
    end

    def inter_state?(branch, customer)
      branch_code   = branch&.state_code.to_s.strip
      customer_code = customer&.gstin.to_s.strip.first(2)

      return false if branch_code.blank? || customer_code.blank?
      branch_code != customer_code
    end

    def in_b2c_large?(inv)
      inv.customer.gstin.blank? &&
        inv.grand_total.to_d >= B2C_LARGE_THRESHOLD &&
        inter_state?(inv.branch, inv.customer)
    end

    def place_of_supply_code(inv)
      customer = inv.customer
      if customer.gstin.present?
        customer.gstin[0..1]
      else
        billing = customer.respond_to?(:addresses) ?
                    (customer.addresses.find { |a| a.label == 'billing' } || customer.addresses.first) :
                    nil
        state_to_code(billing&.state || inv.branch.state)
      end
    end

    # Map state name to 2-digit GST state code
    def state_to_code(state_name)
      STATE_CODES[state_name.to_s.downcase.strip] || '00'
    end

    STATE_CODES = {
      'jammu and kashmir' => '01', 'himachal pradesh' => '02', 'punjab' => '03',
      'chandigarh' => '04', 'uttarakhand' => '05', 'haryana' => '06',
      'delhi' => '07', 'rajasthan' => '08', 'uttar pradesh' => '09',
      'bihar' => '10', 'sikkim' => '11', 'arunachal pradesh' => '12',
      'nagaland' => '13', 'manipur' => '14', 'mizoram' => '15',
      'tripura' => '16', 'meghalaya' => '17', 'assam' => '18',
      'west bengal' => '19', 'jharkhand' => '20', 'odisha' => '21',
      'chhattisgarh' => '22', 'madhya pradesh' => '23', 'gujarat' => '24',
      'dadra and nagar haveli' => '26', 'daman and diu' => '25',
      'maharashtra' => '27', 'andhra pradesh' => '37', 'karnataka' => '29',
      'goa' => '30', 'lakshadweep' => '31', 'kerala' => '32',
      'tamil nadu' => '33', 'puducherry' => '34', 'andaman and nicobar' => '35',
      'telangana' => '36', 'ladakh' => '38'
    }.freeze
  end
end
