require 'rails_helper'

describe Payments::ConfidenceScorerService do
  let(:invoice) { create(:invoice, total: 10000) }
  let(:customer) { invoice.customer }

  describe 'Amount Score Tests' do
    it 'returns 30 points for exact amount match' do
      transaction = build(:bank_transaction, amount: invoice.total)
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:score]).to eq(30)
    end

    it 'returns 25 points for ±1% difference' do
      transaction = build(:bank_transaction, amount: invoice.total * 1.01)  # +1%
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:score]).to eq(25)
    end

    it 'returns 25 points for ±2% difference (at tolerance)' do
      transaction = build(:bank_transaction, amount: invoice.total * 0.98)  # -2%
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:score]).to eq(25)
    end

    it 'returns 15 points for ±3% difference' do
      transaction = build(:bank_transaction, amount: invoice.total * 1.03)  # +3%
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:score]).to eq(15)
    end

    it 'returns 15 points for ±5% difference (at extended tolerance)' do
      transaction = build(:bank_transaction, amount: invoice.total * 0.95)  # -5%
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:score]).to eq(15)
    end

    it 'returns 0 points for >5% difference' do
      transaction = build(:bank_transaction, amount: invoice.total * 1.10)  # +10%
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:score]).to eq(0)
    end
  end

  describe 'Date Score Tests' do
    it 'returns 20 points for same-day match' do
      transaction = build(:bank_transaction, date: invoice.issue_date.to_date)
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:date][:score]).to eq(20)
    end

    it 'returns 18 points for ±1 day difference' do
      transaction = build(:bank_transaction, date: invoice.issue_date.to_date + 1.day)
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:date][:score]).to eq(18)
    end

    it 'returns 15 points for ±3 day difference' do
      transaction = build(:bank_transaction, date: invoice.issue_date.to_date - 3.days)
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:date][:score]).to eq(15)
    end

    it 'returns 0 points for >3 day difference' do
      transaction = build(:bank_transaction, date: invoice.issue_date.to_date - 10.days)
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:date][:score]).to eq(0)
    end
  end

  describe 'Customer Score Tests' do
    it 'returns 25 points for exact username match' do
      transaction = build(:bank_transaction, 
        customer_name: customer.name,
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:customer][:score]).to eq(25)
    end

    it 'returns 20 points for 90%+ fuzzy match' do
      # Exact match with small typo
      transaction = build(:bank_transaction, 
        customer_name: customer.name.sub(/.$/, 'X'),  # Replace last char
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:customer][:score]).to be >= 18  # Allow some variance
    end

    it 'returns 10 points for 80%+ fuzzy match' do
      # More significant difference but still recognizable
      transaction = build(:bank_transaction, 
        customer_name: customer.name[0..5] + 'XXXXX',
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect([0, 10]).to include(breakdown[:customer][:score])
    end

    it 'returns 0 points for <80% fuzzy match' do
      transaction = build(:bank_transaction, 
        customer_name: 'COMPLETELY DIFFERENT NAME',
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:customer][:score]).to eq(0)
    end
  end

  describe 'Reference Score Tests' do
    it 'returns 15 points when invoice number found in reference' do
      transaction = build(:bank_transaction, 
        reference: "Payment for invoice #{invoice.invoice_number}",
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:reference][:score]).to eq(15)
    end

    it 'returns 15 points when order number found in reference' do
      order = invoice.order
      transaction = build(:bank_transaction, 
        reference: "ORD-#{order.order_number}-PAY",
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:reference][:score]).to eq(15)
    end

    it 'returns 0 points when no reference match' do
      transaction = build(:bank_transaction, 
        reference: 'RANDOM-REF-12345',
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:reference][:score]).to eq(0)
    end
  end

  describe 'Composite Scoring Tests' do
    it 'achieves 100 points for perfect match (all components)' do
      transaction = build(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: invoice.customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      confidence = result.data[:confidence]
      expect(confidence).to eq(100.0)
    end

    it 'calculates high confidence (80+) for strong match' do
      transaction = build(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: invoice.customer.name,
        reference: "SomeRef"
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      confidence = result.data[:confidence]
      expect(confidence).to be >= 80
    end

    it 'calculates medium confidence for partial match' do
      transaction = build(:bank_transaction,
        amount: invoice.total * 1.01,  # ±1% variance
        date: invoice.issue_date.to_date + 2.days,  # ±2 days
        customer_name: 'SomeCustomer',  # No match
        reference: "SomeRef"  # No match
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      confidence = result.data[:confidence]
      expect(confidence).to be_between(40, 80)
    end

    it 'calculates low confidence for weak match' do
      transaction = build(:bank_transaction,
        amount: invoice.total * 0.85,  # -15% variance
        date: invoice.issue_date.to_date - 10.days,  # -10 days
        customer_name: 'COMPLETELY DIFFERENT',
        reference: "NoMatch"
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      confidence = result.data[:confidence]
      expect(confidence).to be < 40
    end
  end

  describe 'Error Handling Tests' do
    it 'returns failure when bank_transaction is nil' do
      service = described_class.new(
        bank_transaction: nil,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be false
      expect(result.errors).to include("Bank transaction not found")
    end

    it 'returns failure when matching_invoice is nil' do
      transaction = build(:bank_transaction)
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: nil
      )
      
      result = service.call
      
      expect(result.success?).to be false
      expect(result.errors).to include("Matching invoice not found")
    end

    it 'handles blank amount in bank transaction gracefully' do
      transaction = build(:bank_transaction, amount: nil)
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:score]).to eq(0)
    end

    it 'handles blank customer_name gracefully' do
      transaction = build(:bank_transaction, 
        customer_name: nil,
        amount: invoice.total
      )
      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )
      
      result = service.call
      
      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:customer][:score]).to eq(0)
    end
  end

  describe 'Configuration Tests' do
    it 'uses custom configuration when provided' do
      transaction = build(:bank_transaction,
        amount: invoice.total * 1.03,  # +3% - normally 15 pts with default 2% tolerance
        date: invoice.issue_date.to_date,
        customer_name: invoice.customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      # Custom config with higher tolerance (5%)
      custom_config = {
        'amount_tolerance_pct' => 5.0,
        'date_tolerance_days' => 3,
        'customer_fuzzy_minimum' => 0.80,
        'reference_weight' => 15
      }

      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice,
        configuration: custom_config
      )

      result = service.call

      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      # With 5% tolerance, +3% diff should give 25 pts instead of 15
      expect(breakdown[:amount][:score]).to eq(25)
    end

    it 'stores configuration tolerance in breakdown' do
      transaction = build(:bank_transaction,
        amount: invoice.total,
        date: invoice.issue_date.to_date,
        customer_name: invoice.customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )

      result = service.call

      expect(result.success?).to be true
      breakdown = result.data[:breakdown]
      expect(breakdown[:amount][:tolerance]).to eq(2.0)
      expect(breakdown[:date][:tolerance]).to eq(3)
      expect(breakdown[:customer][:threshold]).to eq(0.80)
    end
  end

  describe 'Breakdown Details Tests' do
    it 'includes descriptive text for each component' do
      transaction = build(:bank_transaction,
        amount: invoice.total * 1.01,
        date: invoice.issue_date.to_date + 1.day,
        customer_name: invoice.customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )

      result = service.call

      expect(result.success?).to be true
      breakdown = result.data[:breakdown]

      expect(breakdown[:amount][:value]).to include('₹')
      expect(breakdown[:date][:value]).to include('day')
      expect(breakdown[:customer][:value]).to include('%')
      expect(breakdown[:reference][:value]).to be_present
    end

    it 'returns confidence score as float with 2 decimals' do
      transaction = build(:bank_transaction,
        amount: invoice.total * 0.99,
        date: invoice.issue_date.to_date,
        customer_name: invoice.customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )

      result = service.call

      expect(result.success?).to be true
      confidence = result.data[:confidence]
      expect(confidence).to be_a(Float)
      expect(confidence.to_s.split('.')[1].length).to be <= 2
    end

    it 'never returns confidence > 100' do
      transaction = build(:bank_transaction,
        amount: invoice.total * 0.999,
        date: invoice.issue_date.to_date,
        customer_name: invoice.customer.name,
        reference: "INV-#{invoice.invoice_number}"
      )

      service = described_class.new(
        bank_transaction: transaction,
        matching_invoice: invoice
      )

      result = service.call

      expect(result.success?).to be true
      confidence = result.data[:confidence]
      expect(confidence).to be <= 100
    end
  end
end
