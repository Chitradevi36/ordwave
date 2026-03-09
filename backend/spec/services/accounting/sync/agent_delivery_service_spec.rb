# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting::Sync::AgentDeliveryService do
  let(:organization) { create(:organization) }
  let(:integration) do
    create(:accounting_integration,
           organization: organization,
           sync_mode: :realtime_agent)
  end
  let(:sync_record) do
    create(:accounting_sync_record,
           organization: organization,
           accounting_integration: integration,
           status: 'processing',
           attempt_count: 1,
           processing_started_at: 1.minute.ago)
  end

  describe '#mark_delivered' do
    it 'updates record status to success' do
      service = described_class.new(sync_record)
      service.mark_delivered

      sync_record.reload
      expect(sync_record.status).to eq('success')
      expect(sync_record.completed_at).to be_present
      expect(sync_record.response_body).to include('Delivered via agent')
    end

    it 'sets completed_at to current time' do
      service = described_class.new(sync_record)

      Timecop.freeze do
        service.mark_delivered
        sync_record.reload
        expect(sync_record.completed_at).to be_within(1.second).of(Time.current)
      end
    end

    it 'clears error_message if present' do
      sync_record.update!(error_message: 'Previous error')
      service = described_class.new(sync_record)
      service.mark_delivered

      sync_record.reload
      expect(sync_record.error_message).to be_nil
    end
  end

  describe '#mark_failed' do
    let(:service) { described_class.new(sync_record) }
    let(:error_message) { 'Connection timeout to Tally' }

    context 'when attempt_count is below MAX_RETRIES' do
      before do
        sync_record.update!(attempt_count: 1)
      end

      it 'sets status to retrying' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.status).to eq('retrying')
      end

      it 'stores the error message' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.error_message).to eq(error_message)
      end

      it 'clears processing_started_at' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.processing_started_at).to be_nil
      end

      it 'does not set completed_at' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.completed_at).to be_nil
      end
    end

    context 'when attempt_count reaches MAX_RETRIES' do
      before do
        sync_record.update!(attempt_count: AccountingSyncRecord::MAX_RETRIES)
      end

      it 'sets status to failed' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.status).to eq('failed')
      end

      it 'stores the error message' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.error_message).to eq(error_message)
      end

      it 'sets completed_at' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.completed_at).to be_present
      end

      it 'clears processing_started_at' do
        service.mark_failed(error_message)

        sync_record.reload
        expect(sync_record.processing_started_at).to be_nil
      end
    end

    context 'when error message is very long' do
      let(:long_error) { 'Error: ' + 'X' * 1000 }

      it 'stores the full error message' do
        service.mark_failed(long_error)

        sync_record.reload
        expect(sync_record.error_message).to eq(long_error)
      end
    end

    context 'when error message is nil' do
      it 'stores a default error message' do
        service.mark_failed(nil)

        sync_record.reload
        expect(sync_record.error_message).to be_present
        expect(sync_record.error_message).to include('Unknown')
      end
    end
  end

  describe 'edge cases' do
    let(:service) { described_class.new(sync_record) }

    it 'handles concurrent updates gracefully' do
      # Simulate concurrent update
      sync_record.update_columns(status: 'success')

      expect {
        service.mark_failed('Test error')
      }.not_to raise_error
    end
  end
end
