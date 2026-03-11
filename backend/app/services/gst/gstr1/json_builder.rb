# frozen_string_literal: true

module Gst
  module Gstr1
    # Builds the official GSTR-1 JSON payload accepted by the GST portal.
    #
    # Portal specification reference:
    #   https://developer.gst.gov.in/apiportal/taxpayer/returns
    #
    # Sections produced:
    #   b2b       — invoices to registered dealers (GSTIN present)
    #   b2cl      — invoices to unregistered, inter-state, over ₹2.5L
    #   b2cs      — invoices to unregistered, intra/small inter-state
    #   cdnr      — credit notes to registered dealers
    #   cdnur     — credit notes to unregistered buyers
    #   hsn       — HSN-wise summary
    #   doc_issue — document series summary (invoice & credit-note numbering)
    #
    # Usage:
    #   json = Gst::Gstr1::JsonBuilder.call(
    #     gstin:             "27ABCDE1234F1ZP",
    #     return_period:     "032026",              # MMYYYY
    #     b2b_invoices:      [...],
    #     b2cl_invoices:     [...],
    #     b2cs_invoices:     [...],
    #     cdnr_notes:        [...],
    #     cdnur_notes:       [...],
    #     seller_state_code: "27"
    #   )
    #
    class JsonBuilder
      def self.call(**kwargs)
        new(**kwargs).call
      end

      def initialize(gstin:, return_period:, b2b_invoices:, b2cl_invoices:,
                     b2cs_invoices:, cdnr_notes:, cdnur_notes:, seller_state_code:)
        @gstin             = gstin
        @return_period     = return_period
        @b2b_invoices      = b2b_invoices
        @b2cl_invoices     = b2cl_invoices
        @b2cs_invoices     = b2cs_invoices
        @cdnr_notes        = cdnr_notes
        @cdnur_notes       = cdnur_notes
        @seller_state_code = seller_state_code
        @all_invoices      = b2b_invoices + b2cl_invoices + b2cs_invoices
        @all_credit_notes  = cdnr_notes + cdnur_notes
      end

      def call
        {
          gstin:     @gstin,
          fp:        @return_period,
          gt:        nil,
          cur_gt:    nil,
          b2b:       build_b2b,
          b2cl:      build_b2cl,
          b2cs:      build_b2cs,
          cdnr:      build_cdnr,
          cdnur:     build_cdnur,
          hsn:       { data: build_hsn },
          doc_issue: build_doc_issue
        }
      end

      private

      # ── B2B ─────────────────────────────────────────────────────────────────

      def build_b2b
        @b2b_invoices.group_by { |inv| inv.customer.gstin }.map do |gstin, invs|
          {
            ctin: gstin,
            inv:  invs.map { |inv| format_b2b_invoice(inv) }
          }
        end
      end

      def format_b2b_invoice(inv)
        is_inter = inter_state_invoice?(inv)

        {
          inum:    inv.invoice_number,
          idt:     inv.invoice_date.strftime('%d-%m-%Y'),
          val:     round(inv.grand_total),
          pos:     SectionClassifier.place_of_supply_code(inv),
          rchrg:   'N',
          inv_typ: 'R',
          itms:    build_invoice_line_items(inv.lines, is_inter)
        }
      end

      # ── B2CL ────────────────────────────────────────────────────────────────

      def build_b2cl
        @b2cl_invoices.map do |inv|
          {
            pos:  SectionClassifier.place_of_supply_code(inv),
            inum: inv.invoice_number,
            idt:  inv.invoice_date.strftime('%d-%m-%Y'),
            val:  round(inv.grand_total),
            itms: build_invoice_line_items(inv.lines, true) # always inter-state
          }
        end
      end

      # ── B2CS ────────────────────────────────────────────────────────────────
      # Aggregated by POS + rate + supply type

      def build_b2cs
        aggregated = {}

        @b2cs_invoices.each do |inv|
          is_inter = inter_state_invoice?(inv)
          pos      = SectionClassifier.place_of_supply_code(inv)
          sply_ty  = is_inter ? 'INTER' : 'INTRA'

          inv.lines.each do |line|
            key = "#{pos}_#{line.gst_rate}_#{sply_ty}"
            aggregated[key] ||= {
              pos:     pos,
              sply_ty: sply_ty,
              rt:      line.gst_rate.to_f,
              txval:   0.0,
              camt:    0.0,
              samt:    0.0,
              iamt:    0.0,
              csamt:   0.0
            }
            agg = aggregated[key]
            agg[:txval] += line.taxable_value.to_f

            if is_inter
              agg[:iamt] += line.igst_amount.to_f
            else
              agg[:camt] += line.cgst_amount.to_f
              agg[:samt] += line.sgst_amount.to_f
            end
            agg[:csamt] += line.cess_amount.to_f
          end
        end

        aggregated.values.map { |h| round_hash_floats(h) }
      end

      # ── CDNR ────────────────────────────────────────────────────────────────

      def build_cdnr
        @cdnr_notes.group_by { |cn| cn.customer.gstin }.map do |gstin, notes|
          {
            ctin: gstin,
            nt:   notes.map { |cn| format_credit_note(cn) }
          }
        end
      end

      # ── CDNUR ───────────────────────────────────────────────────────────────

      def build_cdnur
        @cdnur_notes.map { |cn| format_credit_note(cn).merge(typ: 'B2CL') }
      end

      def format_credit_note(cn)
        is_inter = cn.customer&.gstin.present? ?
                     @seller_state_code != cn.customer.gstin[0..1] :
                     false

        {
          ntty:   'C',
          nt_num: cn.credit_note_number,
          nt_dt:  cn.issued_at&.strftime('%d-%m-%Y') || cn.created_at.strftime('%d-%m-%Y'),
          val:    round(cn.total),
          itms:   build_credit_note_line_items(cn.lines, is_inter)
        }
      end

      # ── HSN Summary ─────────────────────────────────────────────────────────

      def build_hsn
        hsn_data = {}

        @all_invoices.each do |inv|
          is_inter = inter_state_invoice?(inv)
          inv.lines.each { |line| add_invoice_line_to_hsn(hsn_data, line, is_inter) }
        end

        @all_credit_notes.each do |cn|
          is_inter = cn.customer&.gstin.present? ?
                       @seller_state_code != cn.customer.gstin[0..1] :
                       false
          cn.lines.each { |line| subtract_credit_line_from_hsn(hsn_data, line, is_inter) }
        end

        hsn_data.values.map { |h| round_hash_floats(h) }
      end

      def add_invoice_line_to_hsn(hsn_data, line, is_inter)
        key = hsn_key(line)
        hsn_data[key] ||= new_hsn_row(line)
        h = hsn_data[key]
        h[:cnt]   += 1
        h[:qty]   += line.qty.to_f
        h[:txval] += line.taxable_value.to_f
        if is_inter
          h[:iamt] += line.igst_amount.to_f
        else
          h[:camt] += line.cgst_amount.to_f
          h[:samt] += line.sgst_amount.to_f
        end
        h[:csamt] += line.cess_amount.to_f
      end

      def subtract_credit_line_from_hsn(hsn_data, line, is_inter)
        key     = "#{line.hsn_code.presence || 'UNKNOWN'}_#{line.gst_rate}"
        taxable = line.line_total.to_f - line.tax_amount.to_f
        tax     = line.tax_amount.to_f

        hsn_data[key] ||= {
          hsn_sc: line.hsn_code.presence || 'UNKNOWN',
          desc:   line.product&.name.to_s.truncate(30),
          uqc:    line.product&.units_of_measure&.symbol || 'NOS',
          cnt:    0, qty: 0.0, rt: line.gst_rate.to_f,
          txval: 0.0, iamt: 0.0, camt: 0.0, samt: 0.0, csamt: 0.0
        }

        h = hsn_data[key]
        h[:qty]   -= line.qty.to_f
        h[:txval] -= taxable
        if is_inter
          h[:iamt] -= tax
        else
          half = (tax / 2).round(2)
          h[:camt] -= half
          h[:samt] -= half
        end
      end

      def new_hsn_row(line)
        {
          hsn_sc: line.hsn_code.presence || line.product&.hsn_code.presence || 'UNKNOWN',
          desc:   line.product&.name.to_s.truncate(30),
          uqc:    line.product&.units_of_measure&.symbol || 'NOS',
          cnt:    0,
          qty:    0.0,
          rt:     line.gst_rate.to_f,
          txval:  0.0,
          iamt:   0.0,
          camt:   0.0,
          samt:   0.0,
          csamt:  0.0
        }
      end

      def hsn_key(line)
        "#{line.hsn_code.presence || line.product&.hsn_code.presence || 'UNKNOWN'}_#{line.gst_rate}"
      end

      # ── Document Issue ───────────────────────────────────────────────────────
      # Summarises the invoice and credit-note series issued during the period.

      def build_doc_issue
        return [] if @all_invoices.empty? && @all_credit_notes.empty?

        det = []

        unless @all_invoices.empty?
          sorted = @all_invoices.sort_by(&:invoice_number)
          det << {
            doc_num:   1,
            doc_from:  sorted.first.invoice_number,
            doc_to:    sorted.last.invoice_number,
            totnum:    sorted.size,
            cancel:    0,
            net_issue: sorted.size
          }
        end

        unless @all_credit_notes.empty?
          sorted = @all_credit_notes.sort_by { |cn| cn.credit_note_number.to_s }
          det << {
            doc_num:   2,
            doc_from:  sorted.first.credit_note_number,
            doc_to:    sorted.last.credit_note_number,
            totnum:    sorted.size,
            cancel:    0,
            net_issue: sorted.size
          }
        end

        [{ doc_det: det }]
      end

      # ── Rate-item builders ───────────────────────────────────────────────────

      def build_invoice_line_items(lines, is_inter)
        lines.group_by(&:gst_rate).map.with_index(1) do |(rate, rate_lines), idx|
          {
            num:     idx,
            itm_det: {
              rt:    rate.to_f,
              txval: round(rate_lines.sum { |l| l.taxable_value.to_d }),
              camt:  is_inter ? 0.0 : round(rate_lines.sum { |l| l.cgst_amount.to_d }),
              samt:  is_inter ? 0.0 : round(rate_lines.sum { |l| l.sgst_amount.to_d }),
              iamt:  is_inter ? round(rate_lines.sum { |l| l.igst_amount.to_d }) : 0.0,
              csamt: round(rate_lines.sum { |l| l.cess_amount.to_d })
            }
          }
        end
      end

      def build_credit_note_line_items(lines, is_inter)
        lines.group_by(&:gst_rate).map.with_index(1) do |(rate, rate_lines), idx|
          taxable = rate_lines.sum { |l| l.line_total.to_d - l.tax_amount.to_d }
          tax     = rate_lines.sum { |l| l.tax_amount.to_d }

          {
            num:     idx,
            itm_det: {
              rt:    rate.to_f,
              txval: round(taxable),
              camt:  is_inter ? 0.0 : round(tax / 2),
              samt:  is_inter ? 0.0 : round(tax / 2),
              iamt:  is_inter ? round(tax) : 0.0,
              csamt: 0.0
            }
          }
        end
      end

      # ── Helpers ──────────────────────────────────────────────────────────────

      def inter_state_invoice?(inv)
        SectionClassifier.inter_state?(inv, seller_state_code: @seller_state_code)
      end

      def round(val)
        val.to_d.round(2).to_f
      end

      def round_hash_floats(h)
        h.transform_values { |v| v.is_a?(Float) ? v.round(2) : v }
      end
    end
  end
end
