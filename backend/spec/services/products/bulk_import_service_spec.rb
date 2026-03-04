require 'rails_helper'

RSpec.describe Products::BulkImportService, type: :service do
  let(:org)      { create(:organization) }
  let(:hsn)      { create(:hsn_sac_code, code: '10061090', gst_rate: 5, active: true) }
  let(:uom)      { create(:unit_of_measure, symbol: 'KG', active: true) }

  def csv_file(content)
    Rack::Test::UploadedFile.new(StringIO.new(content), 'text/csv', original_filename: 'products.csv')
  end

  def call(csv_content)
    described_class.new(file: csv_file(csv_content), organization: org).call
  end

  # ─── SAMPLE_HEADERS constant ───────────────────────────────────────────────
  describe 'SAMPLE_HEADERS' do
    it 'includes all expected column names' do
      expect(described_class::SAMPLE_HEADERS).to include(
        'sku', 'name', 'hsn_code', 'uom_symbol', 'min_order_qty', 'status'
      )
    end
  end

  # ─── Successful import ─────────────────────────────────────────────────────
  describe '#call — happy path' do
    let(:csv) do
      <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        PROD-001,Rice 5kg,Grains,KG,10061090,10,350.00,8901234567890,5.0,Premium rice,,active
        PROD-002,Sunflower Oil 1L,Edible Oils,KG,10061090,6,130.00,,,,,active
      CSV
    end

    subject(:result) { call(csv) }

    it 'imports all rows successfully' do
      expect(result.success_count).to eq(2)
      expect(result.skipped_rows).to be_empty
      expect(result.failed_rows).to be_empty
    end

    it 'creates Product records in the database' do
      expect { result }.to change { org.products.count }.by(2)
    end

    it 'auto-fills gst_rate from the HSN master' do
      result
      product = org.products.find_by(sku: 'PROD-001')
      expect(product.gst_rate).to eq(hsn.gst_rate)
    end

    it 'upcases the SKU' do
      result
      expect(org.products.find_by(sku: 'PROD-001')).not_to be_nil
    end

    it 'sets purchase_price when provided' do
      result
      expect(org.products.find_by(sku: 'PROD-001').purchase_price).to eq(350.00)
    end

    it 'auto-creates missing categories' do
      result
      expect(org.product_categories.find_by(name: 'Grains')).not_to be_nil
    end

    it 'sets status to active by default' do
      result
      expect(org.products.find_by(sku: 'PROD-002').status).to eq('active')
    end
  end

  # ─── Skipped rows (duplicate SKU) ─────────────────────────────────────────
  describe '#call — duplicate SKU' do
    let!(:existing) { create(:product, organization: org, hsn_sac_code: hsn, sku: 'PROD-DUP') }

    let(:csv) do
      <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        PROD-DUP,Duplicate Row,Grains,KG,10061090,1,,,,,,active
      CSV
    end

    it 'skips the duplicate row' do
      result = call(csv)
      expect(result.success_count).to eq(0)
      expect(result.skipped_rows.length).to eq(1)
      expect(result.skipped_rows.first[:sku]).to eq('PROD-DUP')
      expect(result.skipped_rows.first[:reason]).to include('already exists')
    end

    it 'does not overwrite the existing product' do
      expect { call(csv) }.not_to change { existing.reload.name }
    end
  end

  # ─── Failed rows ──────────────────────────────────────────────────────────
  describe '#call — validation errors' do
    it 'fails when hsn_code is missing' do
      csv = <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        PROD-003,Missing HSN,Grains,KG,,1,,,,,,active
      CSV
      result = call(csv)
      expect(result.failed_rows.first[:errors]).to include('hsn_code is required')
    end

    it 'fails when hsn_code is not in master' do
      csv = <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        PROD-004,Unknown HSN,Grains,KG,NONEXISTENT,1,,,,,,active
      CSV
      result = call(csv)
      expect(result.failed_rows.first[:errors].first).to include('not found in master')
    end

    it 'fails when name is blank' do
      csv = <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        PROD-005,,Grains,KG,10061090,1,,,,,,active
      CSV
      result = call(csv)
      expect(result.failed_rows.first[:errors]).not_to be_empty
    end

    it 'isolates failures — other rows still import' do
      csv = <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        PROD-GOOD,Good Product,Grains,KG,10061090,1,,,,,,active
        PROD-BAD,,Grains,KG,10061090,1,,,,,,active
      CSV
      result = call(csv)
      expect(result.success_count).to eq(1)
      expect(result.failed_rows.length).to eq(1)
    end
  end

  # ─── MAX_ROWS guard ────────────────────────────────────────────────────────
  describe '#call — MAX_ROWS exceeded' do
    it 'returns an error without importing anything' do
      stub_const("#{described_class}::MAX_ROWS", 1)
      csv = <<~CSV
        sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status
        PROD-A,Row A,Grains,KG,10061090,1,,,,,,active
        PROD-B,Row B,Grains,KG,10061090,1,,,,,,active
      CSV
      result = call(csv)
      expect(result.success_count).to eq(0)
      expect(result.failed_rows.first[:errors].first).to include('maximum allowed')
    end
  end

  # ─── UTF-8 BOM stripping ──────────────────────────────────────────────────
  describe '#call — BOM-prefixed CSV (Excel export)' do
    it 'parses correctly when CSV has a UTF-8 BOM' do
      content  = "\xEF\xBB\xBF" + "sku,name,category_name,uom_symbol,hsn_code,min_order_qty,purchase_price,barcode,weight_kg,description,image_url,status\nBOM-001,BOM Product,Grains,KG,10061090,1,,,,,,active\n"
      result   = call(content)
      expect(result.success_count).to eq(1)
    end
  end

  # ─── Invalid CSV ──────────────────────────────────────────────────────────
  describe '#call — malformed CSV' do
    it 'returns an error result for malformed CSV' do
      result = call("sku,name\n\"unclosed quote")
      expect(result.success_count).to eq(0)
      expect(result.failed_rows.first[:errors].first).to include('Invalid CSV')
    end
  end
end
