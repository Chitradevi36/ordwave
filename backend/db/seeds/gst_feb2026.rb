# frozen_string_literal: true

# ==============================================================================
#  GST Feb 2026 seed — GSTR-1, GSTR-2B, GSTR-3B sample data
#
#  Covers: FY 2025-26 | Period: February 2026 (month=2, year=2026)
#  Organisation: Arya Rice Distributors (Telangana, state-code 36)
#
#  Creates:
#    1. FinancialYear FY2025-26 (find_or_create)
#    2. Gstr1ExportRecord for Feb 2026 (completed)
#    3. GstReturnPeriod [gstr1]      + GstReturnSnapshot (filed)
#    4. GstReturnPeriod [gstr3b]     + GstReturnSnapshot (filed)
#    5. GstReturnPeriod [gstr2b_import] (generated)
#    6. Gst2bImport + 10 Gst2bImportLines (4 matched, 2 missing_in_books,
#                                           1 tax_mismatch, 3 pending/debit-note)
#    7. 4× GstReconciliationIssues linked to the import
# ==============================================================================

puts '== GST Feb 2026 Seed =='

org    = Organization.first
branch = org.branches.first
user   = org.users.first

# ── Ensure org has a GSTIN ────────────────────────────────────────────────────
unless org.gst_number.present?
  org.update_column(:gst_number, '36AABCA1234B1ZB')
  puts "  Set org GSTIN: #{org.gst_number}"
end

org_gstin    = org.gst_number
period_from  = Date.new(2026, 2, 1)
period_to    = Date.new(2026, 2, 28)
period_label = '022026'   # MMYYYY format used by GSTN portal

# ── 1. Financial Year ─────────────────────────────────────────────────────────
fy = FinancialYear.find_or_create_by!(organization: org, code: 'FY2025-26') do |f|
  f.label      = 'FY 2025-26'
  f.start_date = Date.new(2025, 4, 1)
  f.end_date   = Date.new(2026, 3, 31)
  f.status     = 'open'
end
puts "  FinancialYear: #{fy.code} (#{fy.start_date} → #{fy.end_date})"

# ── 2. GSTR-1 Export Record ───────────────────────────────────────────────────
gstr1_export = Gstr1ExportRecord.find_or_create_by!(
  organization:  org,
  return_period: period_label
) do |r|
  r.branch              = nil
  r.generated_by        = user
  r.gstin               = org_gstin
  r.period_from         = period_from
  r.period_to           = period_to
  r.status              = 'completed'
  r.b2b_count           = 8
  r.b2cl_count          = 2
  r.b2cs_count          = 5
  r.cdnr_count          = 1
  r.cdnur_count         = 0
  r.total_invoice_count = 15
  r.total_cn_count      = 1
  r.total_taxable_value  = 482_500.00
  r.total_tax_value      = 24_125.00
  r.total_invoice_value  = 506_625.00
  r.error_count         = 0
  r.warning_count       = 2
  r.validation_report   = {
    'warnings' => [
      '2 invoices missing HSN summary',
      'IGST amounts rounded to 2 decimal places'
    ]
  }
  r.completed_at = Time.new(2026, 3, 5, 10, 30, 0)
end
puts "  Gstr1ExportRecord: #{gstr1_export.return_period} | #{gstr1_export.total_invoice_count} invoices | ₹#{gstr1_export.total_invoice_value}"

# ── 3. GstReturnPeriod — GSTR-1 ──────────────────────────────────────────────
rp_gstr1 = GstReturnPeriod.find_or_create_by!(
  organization:   org,
  financial_year: fy,
  branch:         nil,
  month:          2,
  year:           2026,
  return_type:    'gstr1'
) do |p|
  p.financial_year_label = fy.label
  p.period_start_on      = period_from
  p.period_end_on        = period_to
  p.status               = 'filed'
  p.generated_at         = Time.new(2026, 3, 5, 10, 0, 0)
  p.reviewed_by          = user
  p.locked_by            = user
  p.filed_by             = user
  p.locked_at            = Time.new(2026, 3, 7, 9, 0, 0)
  p.filed_at             = Time.new(2026, 3, 11, 14, 30, 0)
  p.filing_notes         = 'GSTR-1 for Feb 2026 filed successfully on GST portal.'
  p.error_count          = 0
  p.warning_count        = 2
  p.source_hash          = Digest::SHA256.hexdigest("gstr1|#{org.id}|2|2026")[0..15]
  p.snapshot_hash        = Digest::SHA256.hexdigest("snap|gstr1|#{org.id}|2|2026")[0..15]
end
puts "  GstReturnPeriod [gstr1]:  id=#{rp_gstr1.id}  status=#{rp_gstr1.status}"

# GSTR-1 Snapshot — representative B2B, B2CS, CDNR and HSN sections
unless GstReturnSnapshot.exists?(gst_return_period: rp_gstr1, section_key: 'gstr1_full')
  snap_gstr1 = GstReturnSnapshot.create!(
    gst_return_period: rp_gstr1,
    organization:      org,
    section_key:       'gstr1_full',
    generated_at:      Time.new(2026, 3, 5, 10, 5, 0),
    version_number:    1,
    is_filed:          true,
    payload: {
      'b2b' => [
        {
          'ctin' => '36AADCL4567B1ZD',
          'inv'  => [
            { 'inum' => 'SI-ARYA-202602-0001', 'idt' => '05-02-2026', 'val' => 84_700.00,
              'pos' => '36', 'rchrg' => 'N', 'etin' => nil,
              'itms' => [{ 'num' => 1, 'itm_det' => { 'rt' => 5.0, 'txval' => 80_666.67,
                           'iamt' => 0, 'camt' => 2_016.67, 'samt' => 2_016.67, 'csamt' => 0 } }] },
            { 'inum' => 'SI-ARYA-202602-0002', 'idt' => '10-02-2026', 'val' => 56_700.00,
              'pos' => '36', 'rchrg' => 'N', 'etin' => nil,
              'itms' => [{ 'num' => 1, 'itm_det' => { 'rt' => 5.0, 'txval' => 54_000.00,
                           'iamt' => 0, 'camt' => 1_350.00, 'samt' => 1_350.00, 'csamt' => 0 } }] }
          ]
        },
        {
          'ctin' => '37AABCS2345C1ZK',
          'inv'  => [
            { 'inum' => 'SI-ARYA-202602-0003', 'idt' => '15-02-2026', 'val' => 118_300.00,
              'pos' => '36', 'rchrg' => 'N', 'etin' => nil,
              'itms' => [{ 'num' => 1, 'itm_det' => { 'rt' => 18.0, 'txval' => 100_254.24,
                           'iamt' => 18_045.76, 'camt' => 0, 'samt' => 0, 'csamt' => 0 } }] }
          ]
        }
      ],
      'b2cs' => [
        { 'sply_ty' => 'INTRA', 'rt' => 5.0,  'typ' => 'OE', 'pos' => '36',
          'txval' => 42_000.00, 'iamt' => 0, 'camt' => 1_050.00, 'samt' => 1_050.00, 'csamt' => 0 },
        { 'sply_ty' => 'INTRA', 'rt' => 18.0, 'typ' => 'OE', 'pos' => '36',
          'txval' => 18_000.00, 'iamt' => 0, 'camt' => 1_620.00, 'samt' => 1_620.00, 'csamt' => 0 }
      ],
      'cdnr' => [
        {
          'ctin' => '36AADCL4567B1ZD',
          'nt'   => [
            { 'ntty' => 'C', 'nt_num' => 'CN-ARYA-202602-0001', 'nt_dt' => '18-02-2026',
              'val' => 5_250.00, 'pos' => '36', 'rchrg' => 'N',
              'itms' => [{ 'num' => 1, 'itm_det' => { 'rt' => 5.0, 'txval' => 5_000.00,
                           'iamt' => 0, 'camt' => 125.00, 'samt' => 125.00, 'csamt' => 0 } }] }
          ]
        }
      ],
      'hsn' => {
        'data' => [
          { 'num' => 1, 'hsn_sc' => '10061090', 'desc' => 'Rice', 'uqc' => 'KGS',
            'qty' => 8_500.0, 'val' => 357_000.00, 'txval' => 340_000.00,
            'iamt' => 0, 'camt' => 8_500.00, 'samt' => 8_500.00, 'csamt' => 0 },
          { 'num' => 2, 'hsn_sc' => '15121990', 'desc' => 'Refined Sunflower Oil', 'uqc' => 'LTR',
            'qty' => 3_200.0, 'val' => 594_400.00, 'txval' => 566_095.24,
            'iamt' => 0, 'camt' => 14_152.38, 'samt' => 14_152.38, 'csamt' => 0 }
        ]
      }
    },
    totals: {
      'total_taxable'  => 482_500.00,
      'total_igst'     => 18_045.76,
      'total_cgst'     => 9_539.62,
      'total_sgst'     => 9_539.62,
      'total_cess'     => 0.0,
      'total_value'    => 506_625.00,
      'b2b_count'      => 8,
      'b2cs_count'     => 5,
      'cdnr_count'     => 1
    },
    source_counts:  { 'b2b' => 8, 'b2cl' => 2, 'b2cs' => 5, 'cdnr' => 1 },
    source_hash:    rp_gstr1.source_hash,
    snapshot_hash:  rp_gstr1.snapshot_hash
  )
  puts "  GstReturnSnapshot [gstr1_full]: id=#{snap_gstr1.id}"
else
  puts "  GstReturnSnapshot [gstr1_full]: already exists"
end

# ── 4. GstReturnPeriod — GSTR-3B ─────────────────────────────────────────────
rp_gstr3b = GstReturnPeriod.find_or_create_by!(
  organization:   org,
  financial_year: fy,
  branch:         nil,
  month:          2,
  year:           2026,
  return_type:    'gstr3b'
) do |p|
  p.financial_year_label = fy.label
  p.period_start_on      = period_from
  p.period_end_on        = period_to
  p.status               = 'filed'
  p.generated_at         = Time.new(2026, 3, 5, 11, 0, 0)
  p.reviewed_by          = user
  p.locked_by            = user
  p.filed_by             = user
  p.locked_at            = Time.new(2026, 3, 18, 10, 0, 0)
  p.filed_at             = Time.new(2026, 3, 20, 16, 0, 0)
  p.filing_notes         = 'GSTR-3B for Feb 2026 filed with full ITC claimed.'
  p.error_count          = 0
  p.warning_count        = 0
  p.source_hash          = Digest::SHA256.hexdigest("gstr3b|#{org.id}|2|2026")[0..15]
  p.snapshot_hash        = Digest::SHA256.hexdigest("snap|gstr3b|#{org.id}|2|2026")[0..15]
end
puts "  GstReturnPeriod [gstr3b]:  id=#{rp_gstr3b.id}  status=#{rp_gstr3b.status}"

# GSTR-3B Snapshot — Table 3.1 (outward), Table 4 (ITC), Table 5 (nil/exempt)
unless GstReturnSnapshot.exists?(gst_return_period: rp_gstr3b, section_key: 'gstr3b_full')
  snap_gstr3b = GstReturnSnapshot.create!(
    gst_return_period: rp_gstr3b,
    organization:      org,
    section_key:       'gstr3b_full',
    generated_at:      Time.new(2026, 3, 5, 11, 5, 0),
    version_number:    1,
    is_filed:          true,
    payload: {
      'table_3_1' => {
        'outward_taxable_supplies' => {
          'integrated_tax' => 18_045.76, 'central_tax' => 9_539.62,
          'state_ut_tax'   => 9_539.62,  'cess' => 0.0, 'taxable_value' => 482_500.00
        },
        'outward_taxable_zero_rated' => {
          'integrated_tax' => 0.0, 'central_tax' => 0.0,
          'state_ut_tax'   => 0.0, 'cess' => 0.0, 'taxable_value' => 0.0
        },
        'other_outward_supplies' => {
          'integrated_tax' => 0.0, 'central_tax' => 0.0,
          'state_ut_tax'   => 0.0, 'cess' => 0.0, 'taxable_value' => 0.0
        },
        'inward_supplies_reverse_charge' => {
          'integrated_tax' => 0.0, 'central_tax' => 0.0,
          'state_ut_tax'   => 0.0, 'cess' => 0.0, 'taxable_value' => 0.0
        },
        'non_gst_outward_supplies' => { 'taxable_value' => 0.0 }
      },
      'table_4' => {
        'itc_available' => {
          'import_of_goods'       => { 'integrated_tax' => 0.0,        'central_tax' => 0.0,      'state_ut_tax' => 0.0,    'cess' => 0.0 },
          'import_of_services'    => { 'integrated_tax' => 0.0,        'central_tax' => 0.0,      'state_ut_tax' => 0.0,    'cess' => 0.0 },
          'inward_supplies_other' => { 'integrated_tax' => 12_500.00,  'central_tax' => 3_150.00, 'state_ut_tax' => 3_150.00, 'cess' => 0.0 },
          'inward_supplies_isds'  => { 'integrated_tax' => 0.0,        'central_tax' => 0.0,      'state_ut_tax' => 0.0,    'cess' => 0.0 },
          'all_other_itc'         => { 'integrated_tax' => 0.0,        'central_tax' => 0.0,      'state_ut_tax' => 0.0,    'cess' => 0.0 }
        },
        'itc_reversed' => {
          'rule_42_43'      => { 'integrated_tax' => 0.0, 'central_tax' => 0.0, 'state_ut_tax' => 0.0, 'cess' => 0.0 },
          'other_reversals' => { 'integrated_tax' => 0.0, 'central_tax' => 0.0, 'state_ut_tax' => 0.0, 'cess' => 0.0 }
        },
        'net_itc_available' => {
          'integrated_tax' => 12_500.00, 'central_tax' => 3_150.00, 'state_ut_tax' => 3_150.00, 'cess' => 0.0
        },
        'itc_ineligible' => {
          'rule_38'      => { 'integrated_tax' => 0.0, 'central_tax' => 0.0,     'state_ut_tax' => 0.0,     'cess' => 0.0 },
          'section_17_5' => { 'integrated_tax' => 0.0, 'central_tax' => 1_200.00, 'state_ut_tax' => 1_200.00, 'cess' => 0.0 }
        }
      },
      'table_5' => {
        'from_nil_exempt_non_gst' => {
          'inter_state'  => { 'composition_taxable' => 0.0, 'nil_rated' => 0.0,       'exempt' => 0.0, 'non_gst' => 0.0 },
          'intra_state'  => { 'composition_taxable' => 0.0, 'nil_rated' => 42_000.00, 'exempt' => 0.0, 'non_gst' => 0.0 }
        }
      },
      'table_6_1' => {
        'tax_payable' => {
          'integrated_tax' => 18_045.76, 'central_tax' => 9_539.62,  'state_ut_tax' => 9_539.62,  'cess' => 0.0
        },
        'itc_adjusted' => {
          'integrated_tax' => 12_500.00, 'central_tax' => 3_150.00,  'state_ut_tax' => 3_150.00,  'cess' => 0.0
        },
        'tax_cash_paid' => {
          'integrated_tax' => 5_545.76,  'central_tax' => 6_389.62,  'state_ut_tax' => 6_389.62,  'cess' => 0.0
        }
      }
    },
    totals: {
      'outward_taxable_value' => 482_500.00,
      'outward_igst'          => 18_045.76,
      'outward_cgst'          => 9_539.62,
      'outward_sgst'          => 9_539.62,
      'itc_available_igst'    => 12_500.00,
      'itc_available_cgst'    => 3_150.00,
      'itc_available_sgst'    => 3_150.00,
      'net_tax_payable_igst'  => 5_545.76,
      'net_tax_payable_cgst'  => 6_389.62,
      'net_tax_payable_sgst'  => 6_389.62
    },
    source_hash:   rp_gstr3b.source_hash,
    snapshot_hash: rp_gstr3b.snapshot_hash
  )
  puts "  GstReturnSnapshot [gstr3b_full]: id=#{snap_gstr3b.id}"
else
  puts "  GstReturnSnapshot [gstr3b_full]: already exists"
end

# ── 5. GstReturnPeriod — GSTR-2B Import ──────────────────────────────────────
rp_gstr2b = GstReturnPeriod.find_or_create_by!(
  organization:   org,
  financial_year: fy,
  branch:         nil,
  month:          2,
  year:           2026,
  return_type:    'gstr2b_import'
) do |p|
  p.financial_year_label = fy.label
  p.period_start_on      = period_from
  p.period_end_on        = period_to
  p.status               = 'generated'
  p.generated_at         = Time.new(2026, 3, 3, 9, 5, 0)
  p.error_count          = 2
  p.warning_count        = 3
  p.source_hash          = Digest::SHA256.hexdigest("gstr2b_import|#{org.id}|2|2026")[0..15]
  p.snapshot_hash        = Digest::SHA256.hexdigest("snap|gstr2b|#{org.id}|2|2026")[0..15]
end
puts "  GstReturnPeriod [gstr2b_import]: id=#{rp_gstr2b.id}  status=#{rp_gstr2b.status}"

# ── 6. Gst2bImport ───────────────────────────────────────────────────────────
gst2b = Gst2bImport.find_or_create_by!(
  organization:   org,
  financial_year: fy,
  month:          2,
  year:           2026
) do |i|
  i.financial_year_label = fy.label
  i.period_start_on      = period_from
  i.period_end_on        = period_to
  i.gstin                = org_gstin
  i.file_name            = "GSTR2B_#{org_gstin}_022026.json"
  i.source_type          = 'json'
  i.import_status        = 'completed'
  i.total_rows           = 10
  i.matched_rows         = 5
  i.unmatched_rows       = 3
  i.error_rows           = 2
  i.imported_at          = Time.new(2026, 3, 3, 9, 0, 0)
  i.imported_by          = user
  i.raw_payload          = {}
  i.parsed_summary       = {
    'period'        => 'Feb 2026',
    'total_records' => 10,
    'total_igst'    => 12_500.00,
    'total_cgst'    => 3_350.00,
    'total_sgst'    => 3_350.00,
    'suppliers'     => 4,
    'b2b_invoices'  => 9,
    'debit_notes'   => 1
  }
end
puts "  Gst2bImport: id=#{gst2b.id}  status=#{gst2b.import_status}  rows=#{gst2b.total_rows}"

# ── 6a. Gst2bImportLines ──────────────────────────────────────────────────────
if gst2b.gst2b_import_lines.none?
  supp_sharma_gstin  = '27AABCS1429B1ZB'   # Sharma Distributors  (Maharashtra)
  supp_patel_gstin   = '24AACCP1234A1ZK'   # Patel Agro Exports   (Gujarat)
  supp_venkata_gstin = '29AADCA5678K1ZM'   # Sri Venkata Agro     (Karnataka — not in books)
  supp_meenakshi_gstin = '33AABCM8765N1Z2' # Meenakshi Cereals    (Tamil Nadu — not in books)

  lines_data = [
    # ── 4 × matched ─────────────────────────────────────────────────────────
    {
      supplier_gstin: supp_sharma_gstin, supplier_name: 'Sharma Distributors',
      invoice_number: 'SD/2025-26/0284',  invoice_date: Date.new(2026, 2, 3),
      invoice_value: 165_375.00, taxable_value: 157_500.00,
      igst: 0.0, cgst: 3_937.50, sgst: 3_937.50, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'matched', match_confidence: 0.98,
      match_explanation: { 'reason' => 'GSTIN + invoice number exact match',
                           'matched_fields' => %w[gstin invoice_number taxable_value] }
    },
    {
      supplier_gstin: supp_sharma_gstin, supplier_name: 'Sharma Distributors',
      invoice_number: 'SD/2025-26/0291',  invoice_date: Date.new(2026, 2, 10),
      invoice_value: 84_787.50, taxable_value: 80_750.00,
      igst: 0.0, cgst: 2_018.75, sgst: 2_018.75, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'matched', match_confidence: 0.96,
      match_explanation: { 'reason' => 'GSTIN + invoice number match; value within tolerance',
                           'matched_fields' => %w[gstin invoice_number] }
    },
    {
      supplier_gstin: supp_patel_gstin, supplier_name: 'Patel Agro Exports',
      invoice_number: 'PAE/FEB26/0112',  invoice_date: Date.new(2026, 2, 7),
      invoice_value: 110_250.00, taxable_value: 105_000.00,
      igst: 5_250.00, cgst: 0.0, sgst: 0.0, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'matched', match_confidence: 0.99,
      match_explanation: { 'reason' => 'Exact GSTIN, invoice number and amount match',
                           'matched_fields' => %w[gstin invoice_number taxable_value igst] }
    },
    {
      supplier_gstin: supp_patel_gstin, supplier_name: 'Patel Agro Exports',
      invoice_number: 'PAE/FEB26/0118',  invoice_date: Date.new(2026, 2, 18),
      invoice_value: 57_750.00, taxable_value: 55_000.00,
      igst: 2_750.00, cgst: 0.0, sgst: 0.0, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'matched', match_confidence: 0.95,
      match_explanation: { 'reason' => 'Match on GSTIN and invoice number; date ±1 day',
                           'matched_fields' => %w[gstin invoice_number] }
    },
    # ── 2 × missing_in_books ─────────────────────────────────────────────────
    {
      supplier_gstin: supp_venkata_gstin, supplier_name: 'Sri Venkata Agro Pvt Ltd',
      invoice_number: 'SVAPL/0044/2526',   invoice_date: Date.new(2026, 2, 12),
      invoice_value: 42_000.00, taxable_value: 40_000.00,
      igst: 2_000.00, cgst: 0.0, sgst: 0.0, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'missing_in_books', match_confidence: 0.0,
      match_explanation: { 'reason' => 'No matching purchase invoice found in books for this GSTIN',
                           'suggestions' => ['Check if invoice was skipped during data entry'] }
    },
    {
      supplier_gstin: supp_meenakshi_gstin, supplier_name: 'Meenakshi Cereals',
      invoice_number: 'MC/2526/FEB/0077',  invoice_date: Date.new(2026, 2, 20),
      invoice_value: 28_350.00, taxable_value: 27_000.00,
      igst: 1_350.00, cgst: 0.0, sgst: 0.0, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'missing_in_books', match_confidence: 0.0,
      match_explanation: { 'reason' => 'Supplier not registered in system',
                           'suggestions' => ["Create supplier with GSTIN #{supp_meenakshi_gstin} before booking"] }
    },
    # ── 1 × tax_mismatch ─────────────────────────────────────────────────────
    {
      supplier_gstin: supp_sharma_gstin, supplier_name: 'Sharma Distributors',
      invoice_number: 'SD/2025-26/0299',  invoice_date: Date.new(2026, 2, 22),
      invoice_value: 21_420.00, taxable_value: 20_400.00,
      igst: 0.0, cgst: 510.00, sgst: 510.00, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'tax_mismatch', match_confidence: 0.70,
      match_explanation: {
        'reason'          => 'Invoice number matched but tax amounts differ',
        'books_cgst'      => 490.00, 'portal_cgst' => 510.00,
        'books_sgst'      => 490.00, 'portal_sgst' => 510.00,
        'difference'      => 40.00,
        'matched_fields'  => %w[gstin invoice_number],
        'mismatch_fields' => %w[cgst sgst]
      }
    },
    # ── 1 × debit note (matched) ─────────────────────────────────────────────
    {
      supplier_gstin: supp_sharma_gstin, supplier_name: 'Sharma Distributors',
      invoice_number: 'SD/DN/2025-26/0015', invoice_date: Date.new(2026, 2, 15),
      invoice_value: 5_250.00, taxable_value: 5_000.00,
      igst: 0.0, cgst: 125.00, sgst: 125.00, cess: 0.0,
      document_type: 'debit_note', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'matched', match_confidence: 0.92,
      match_explanation: { 'reason' => 'Debit note matched to corresponding purchase record',
                           'matched_fields' => %w[gstin invoice_number document_type] }
    },
    # ── 1 × pending (inter-state, uploaded recently) ─────────────────────────
    {
      supplier_gstin: supp_patel_gstin, supplier_name: 'Patel Agro Exports',
      invoice_number: 'PAE/FEB26/0125',  invoice_date: Date.new(2026, 2, 26),
      invoice_value: 15_750.00, taxable_value: 15_000.00,
      igst: 750.00, cgst: 0.0, sgst: 0.0, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: true,
      match_status: 'pending', match_confidence: 0.0,
      match_explanation: { 'reason' => 'Not yet reconciled — uploaded recently', 'suggestions' => [] }
    },
    # ── 1 × pending (nil-rated, ITC not available) ───────────────────────────
    {
      supplier_gstin: supp_sharma_gstin, supplier_name: 'Sharma Distributors',
      invoice_number: 'SD/2025-26/0305',  invoice_date: Date.new(2026, 2, 25),
      invoice_value: 38_500.00, taxable_value: 38_500.00,
      igst: 0.0, cgst: 0.0, sgst: 0.0, cess: 0.0,
      document_type: 'invoice', section_type: 'b2b', place_of_supply: '36',
      reverse_charge: false, itc_available: false,
      itc_reversal_reason: 'exempt_supply',
      match_status: 'pending', match_confidence: 0.0,
      match_explanation: { 'reason' => 'Nil-rated supply — ITC not claimable',
                           'suggestions' => ['Verify if exempt from ITC under Rule 38'] }
    }
  ]

  lines_data.each do |attrs|
    Gst2bImportLine.create!(
      gst2b_import: gst2b,
      organization: org,
      **attrs
    )
  end
  puts "  Gst2bImportLines: #{gst2b.gst2b_import_lines.reload.count} lines created"
else
  puts "  Gst2bImportLines: #{gst2b.gst2b_import_lines.count} lines (already seeded)"
end

# ── 7. GstReconciliationIssues ────────────────────────────────────────────────
if GstReconciliationIssue.where(gst2b_import: gst2b).none?
  supp_sharma_gstin    = '27AABCS1429B1ZB'
  supp_venkata_gstin   = '29AADCA5678K1ZM'
  supp_meenakshi_gstin = '33AABCM8765N1Z2'

  # Issue 1: missing_in_books — Sri Venkata Agro Pvt Ltd
  GstReconciliationIssue.create!(
    organization:      org,
    financial_year:    fy,
    gst_return_period: rp_gstr2b,
    gst2b_import:      gst2b,
    issue_type:        'missing_in_books',
    severity:          'high',
    supplier_gstin:    supp_venkata_gstin,
    invoice_number:    'SVAPL/0044/2526',
    invoice_date:      Date.new(2026, 2, 12),
    amount_books:      0.0,
    amount_portal:     42_000.00,
    difference_amount: 42_000.00,
    status:            'open',
    metadata: {
      'supplier_name' => 'Sri Venkata Agro Pvt Ltd',
      'itc_at_risk'   => 2_000.00,
      'action'        => 'Book the invoice or obtain credit note from supplier'
    }
  )

  # Issue 2: missing_in_books — Meenakshi Cereals
  GstReconciliationIssue.create!(
    organization:      org,
    financial_year:    fy,
    gst_return_period: rp_gstr2b,
    gst2b_import:      gst2b,
    issue_type:        'missing_in_books',
    severity:          'high',
    supplier_gstin:    supp_meenakshi_gstin,
    invoice_number:    'MC/2526/FEB/0077',
    invoice_date:      Date.new(2026, 2, 20),
    amount_books:      0.0,
    amount_portal:     28_350.00,
    difference_amount: 28_350.00,
    status:            'open',
    metadata: {
      'supplier_name' => 'Meenakshi Cereals',
      'itc_at_risk'   => 1_350.00,
      'action'        => 'Onboard supplier in system and enter invoice'
    }
  )

  # Issue 3: tax_mismatch — Sharma SD/2025-26/0299
  GstReconciliationIssue.create!(
    organization:      org,
    financial_year:    fy,
    gst_return_period: rp_gstr2b,
    gst2b_import:      gst2b,
    issue_type:        'tax_mismatch',
    severity:          'medium',
    supplier_gstin:    supp_sharma_gstin,
    invoice_number:    'SD/2025-26/0299',
    invoice_date:      Date.new(2026, 2, 22),
    amount_books:      980.00,
    amount_portal:     1_020.00,
    difference_amount: 40.00,
    status:            'open',
    metadata: {
      'supplier_name' => 'Sharma Distributors',
      'books_cgst'    => 490.00, 'books_sgst' => 490.00,
      'portal_cgst'   => 510.00, 'portal_sgst' => 510.00,
      'action'        => 'Request revised invoice or debit note from supplier'
    }
  )

  # Issue 4: itc_risk — nil-rated supply (SD/2025-26/0305)
  GstReconciliationIssue.create!(
    organization:      org,
    financial_year:    fy,
    gst_return_period: rp_gstr2b,
    gst2b_import:      gst2b,
    issue_type:        'itc_risk',
    severity:          'medium',
    supplier_gstin:    supp_sharma_gstin,
    invoice_number:    'SD/2025-26/0305',
    invoice_date:      Date.new(2026, 2, 25),
    amount_books:      0.0,
    amount_portal:     0.0,
    difference_amount: 0.0,
    status:            'open',
    metadata: {
      'supplier_name' => 'Sharma Distributors',
      'reason'        => 'ITC marked unavailable — exempt supply under GST (Rule 38)',
      'action'        => 'Confirm with CA before claiming ITC'
    }
  )

  puts "  GstReconciliationIssues: #{GstReconciliationIssue.where(gst2b_import: gst2b).count} issues created"
else
  puts "  GstReconciliationIssues: #{GstReconciliationIssue.where(gst2b_import: gst2b).count} issues (already seeded)"
end

puts ''
puts '== GST Feb 2026 seed complete =='
puts "   FY:                  #{fy.code} (#{fy.start_date} → #{fy.end_date})"
puts "   Org GSTIN:           #{org_gstin}"
puts "   GSTR-1 Period:       id=#{rp_gstr1.id}   status=#{rp_gstr1.status}   filed=#{rp_gstr1.filed_at&.strftime('%d-%b-%Y')}"
puts "   GSTR-3B Period:      id=#{rp_gstr3b.id}  status=#{rp_gstr3b.status}  filed=#{rp_gstr3b.filed_at&.strftime('%d-%b-%Y')}"
puts "   GSTR-2B Period:      id=#{rp_gstr2b.id}  status=#{rp_gstr2b.status}"
puts "   GSTR-2B Import:      id=#{gst2b.id}       lines=#{gst2b.gst2b_import_lines.count}  matched=#{gst2b.matched_rows}  unmatched=#{gst2b.unmatched_rows}"
puts "   Reconciliation issues: #{GstReconciliationIssue.where(gst2b_import: gst2b).count} open"
puts ''
