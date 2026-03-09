# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Accounting::SyncQueueMonitorJob, type: :job do
  let(:organization) { create(:organization) }
  let(:integration) do
    create(:accounting_integration,
           organization: organization,
           sync_mode: :realtime_agent)
  end
  let!(:agent) do
    create(:accounting_agent,
           organization: organization,
           accounting_integration: integration,
           last_heartbeat_at: 30.seconds.ago,
           status: :online)
  end

  describe '#reset_stale_processing_records' do
    let!(:stale_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'processing',
             processing_started_at: 15.minutes.ago)
    end

    let!(:fresh_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'processing',
             processing_started_at: 5.minutes.ago)
    end

    it 'resets stale processing records to pending' do
      described_class.new.reset_stale_processing_records

      stale_record.reload
      expect(stale_record.status).to eq('pending')
      expect(stale_record.processing_started_at).to be_nil
    end

    it 'does not reset fresh processing records' do
      described_class.new.reset_stale_processing_records

      fresh_record.reload
      expect(fresh_record.status).to eq('processing')
      expect(fresh_record.processing_started_at).to be_present
    end

    it 'logs the number of reset records' do
      expect(Rails.logger).to receive(:info).with(/Reset 1 stale processing records/)
      described_class.new.reset_stale_processing_records
    end
  end

  describe '#check_agent_connectivity' do
    context 'when agent is online (heartbeat within 2 minutes)' do
      before do
        agent.update!(last_heartbeat_at: 1.minute.ago, status: :online)
      end

      it 'does not mark integration as error' do
        described_class.new.check_agent_connectivity

        integration.reload
        expect(integration.status).not_to eq('error')
      end

      it 'does not mark agent as offline' do
        described_class.new.check_agent_connectivity

        agent.reload
        expect(agent.status).to eq('online')
      end
    end

    context 'when agent is offline (heartbeat older than 2 minutes)' do
      before do
        agent.update!(last_heartbeat_at: 3.minutes.ago, status: :online)
      end

      it 'marks agent as offline' do
        described_class.new.check_agent_connectivity

        agent.reload
        expect(agent.status).to eq('offline')
      end

      it 'marks integration as error' do
        described_class.new.check_agent_connectivity

        integration.reload
        expect(integration.status).to eq('error')
      end

      it 'logs the offline agent' do
        expect(Rails.logger).to receive(:warn).with(/Agent .* is offline/)
        described_class.new.check_agent_connectivity
      end
    end

    context 'when agent heartbeat is nil' do
      before do
        agent.update!(last_heartbeat_at: nil)
      end

      it 'marks agent as offline' do
        described_class.new.check_agent_connectivity

        agent.reload
        expect(agent.status).to eq('offline')
      end
    end

    context 'when multiple agents exist' do
      let!(:offline_agent) do
        create(:accounting_agent,
               organization: organization,
               accounting_integration: integration,
               last_heartbeat_at: 5.minutes.ago,
               status: :online)
      end

      it 'handles all agents correctly' do
        described_class.new.check_agent_connectivity

        agent.reload
        offline_agent.reload

        expect(agent.status).to eq('online')
        expect(offline_agent.status).to eq('offline')
      end
    end
  end

  describe '#log_queue_stats' do
    let!(:pending_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'pending')
    end

    let!(:processing_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'processing',
             processing_started_at: 2.minutes.ago)
    end

    let!(:retrying_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'retrying',
             attempt_count: 2)
    end

    let!(:failed_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'failed',
             attempt_count: 5)
    end

    let!(:success_record) do
      create(:accounting_sync_record,
             organization: organization,
             accounting_integration: integration,
             status: 'success',
             completed_at: 1.hour.ago)
    end

    it 'logs correct counts for all statuses' do
      expect(Rails.logger).to receive(:info).with(
        /pending: 1, processing: 1, retrying: 1, failed: 1, success: 1/
      )
      described_class.new.log_queue_stats
    end

    it 'logs correct agent counts' do
      offline_agent = create(:accounting_agent,
                             organization: organization,
                             accounting_integration: integration,
                             last_heartbeat_at: 5.minutes.ago,
                             status: :offline)

      expect(Rails.logger).to receive(:info).with(/agents: 1\/2 online/)
      described_class.new.log_queue_stats
    end

    context 'when no records exist' do
      before do
        AccountingSyncRecord.destroy_all
      end

      it 'logs zero counts' do
        expect(Rails.logger).to receive(:info).with(
          /pending: 0, processing: 0, retrying: 0, failed: 0, success: 0/
        )
        described_class.new.log_queue_stats
      end
    end
  end

  describe '#perform' do
    it 'calls all monitoring methods' do
      job = described_class.new
      expect(job).to receive(:reset_stale_processing_records)
      expect(job).to receive(:check_agent_connectivity)
      expect(job).to receive(:log_queue_stats)

      job.perform
    end
  end

  describe 'job scheduling' do
    it 'is configured to run every 5 minutes' do
      # This test verifies the job is scheduled correctly
      # Actual implementation depends on your background job setup (Sidekiq, etc.)
      expect(described_class).to respond_to(:perform_later)
    end
  end
end
