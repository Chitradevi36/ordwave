# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Gst::Gstr2b::Parser, type: :service do
  def sample_payload(overrides = {})
    {
      'data' => {
        'docdata' => {
          'b2b' => [
            {
              'ctin' => '27AAPFU0939F1ZV',
              'trdnm' => 'Test Supplier Pvt Ltd',
              'inv' => [
                {
                  'inum' => 'INV-2025-001',
                  'dt'   => '15-09-2025',
                  'val'  => 118000.0,
                  'rev'  => 'N',
                  'pos'  => '27',
                  'itms' => [
                    {
                      'itm_det' => {
                        'txval' => 100000.0,
                        'iamt'  => 18000.0,
                        'camt'  => 0.0,
                        'samt'  => 0.0,
                        'csamt' => 0.0
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }.merge(overrides)
      }
    }
  end

  describe '.call' do
    context 'with a valid B2B payload' do
      it 'parses successfully' do
        result = described_class.call(json_payload: sample_payload)
        expect(result.success?).to be true
        expect(result.lines.length).to eq(1)
      end

      it 'extracts correct line attributes' do
        result = described_class.call(json_payload: sample_payload)
        line = result.lines.first

        expect(line[:supplier_gstin]).to eq('27AAPFU0939F1ZV')
        expect(line[:supplier_name]).to eq('Test Supplier Pvt Ltd')
        expect(line[:invoice_number]).to eq('INV-2025-001')
        expect(line[:invoice_date]).to eq(Date.new(2025, 9, 15))
        expect(line[:invoice_value]).to eq(118_000.0.to_d)
        expect(line[:taxable_value]).to eq(100_000.0.to_d)
        expect(line[:igst]).to eq(18_000.0.to_d)
        expect(line[:cgst]).to eq(0.0.to_d)
        expect(line[:section_type]).to eq('b2b')
        expect(line[:document_type]).to eq('invoice')
        expect(line[:match_status]).to eq('pending')
        expect(line[:itc_available]).to be true
        expect(line[:reverse_charge]).to be false
      end
    end

    context 'with CDN (credit notes) section' do
      it 'sets document_type to credit_note' do
        payload = sample_payload('cdn' => [
          {
            'ctin' => '27AAPFU0939F1ZV',
            'trdnm' => 'Supplier',
            'inv' => [
              {
                'inum' => 'CN-001',
                'dt'   => '20-09-2025',
                'val'  => 11800.0,
                'itms' => [{ 'itm_det' => { 'txval' => 10000.0, 'iamt' => 1800.0 } }]
              }
            ]
          }
        ])
        result = described_class.call(json_payload: payload)
        cdn_line = result.lines.find { |l| l[:section_type] == 'cdn' }
        expect(cdn_line).to be_present
        expect(cdn_line[:document_type]).to eq('credit_note')
      end
    end

    context 'with flat format (impg)' do
      it 'parses import entries without itms' do
        payload = sample_payload('impg' => [
          {
            'ctin' => '27AAPFU0939F1ZV',
            'trdnm' => 'Import Supplier',
            'inv' => [
              {
                'inum'  => 'IMP-001',
                'dt'    => '10-09-2025',
                'val'   => 50000.0,
                'txval' => 42373.0,
                'iamt'  => 7627.0
              }
            ]
          }
        ])
        result = described_class.call(json_payload: payload)
        impg_line = result.lines.find { |l| l[:section_type] == 'impg' }
        expect(impg_line).to be_present
        expect(impg_line[:igst]).to eq(7627.0.to_d)
      end
    end

    context 'with alternative date format (slash separator)' do
      it 'parses DD/MM/YYYY dates' do
        payload = {
          'data' => {
            'docdata' => {
              'b2b' => [
                {
                  'ctin' => '27AAPFU0939F1ZV',
                  'trdnm' => 'Supplier',
                  'inv' => [
                    {
                      'inum' => 'INV-002',
                      'dt'   => '15/09/2025',
                      'val'  => 118000.0,
                      'itms' => [{ 'itm_det' => { 'txval' => 100000.0, 'iamt' => 18000.0 } }]
                    }
                  ]
                }
              ]
            }
          }
        }
        result = described_class.call(json_payload: payload)
        expect(result.lines.first[:invoice_date]).to eq(Date.new(2025, 9, 15))
      end
    end

    context 'with an invalid / empty payload' do
      it 'returns failure for completely malformed payload' do
        result = described_class.call(json_payload: { 'not_valid' => true })
        expect(result.failure?).to be true
        expect(result.errors).not_to be_empty
      end

      it 'returns empty lines for empty docdata' do
        result = described_class.call(json_payload: { 'data' => { 'docdata' => {} } })
        expect(result.lines).to be_empty
      end
    end

    context 'with multiple suppliers' do
      it 'parses all suppliers and returns all lines' do
        payload = {
          'data' => {
            'docdata' => {
              'b2b' => [
                {
                  'ctin' => '27AAPFU0939F1ZV',
                  'trdnm' => 'Supplier A',
                  'inv' => [
                    { 'inum' => 'INV-A-001', 'dt' => '01-09-2025', 'val' => 118000.0,
                      'itms' => [{ 'itm_det' => { 'txval' => 100000.0, 'iamt' => 18000.0 } }] },
                    { 'inum' => 'INV-A-002', 'dt' => '10-09-2025', 'val' => 23600.0,
                      'itms' => [{ 'itm_det' => { 'txval' => 20000.0, 'iamt' => 3600.0 } }] }
                  ]
                },
                {
                  'ctin' => '29AALCA0943A1ZM',
                  'trdnm' => 'Supplier B',
                  'inv' => [
                    { 'inum' => 'INV-B-001', 'dt' => '05-09-2025', 'val' => 59000.0,
                      'itms' => [{ 'itm_det' => { 'txval' => 50000.0, 'iamt' => 9000.0 } }] }
                  ]
                }
              ]
            }
          }
        }
        result = described_class.call(json_payload: payload)
        expect(result.success?).to be true
        expect(result.lines.length).to eq(3)
        gstins = result.lines.map { |l| l[:supplier_gstin] }.uniq
        expect(gstins).to contain_exactly('27AAPFU0939F1ZV', '29AALCA0943A1ZM')
      end
    end
  end
end
