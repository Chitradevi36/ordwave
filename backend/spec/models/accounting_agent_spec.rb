# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccountingAgent, type: :model do
  # ─── Factories ────────────────────────────────────────────────────────────
  let(:organization) { create(:organization) }
  let(:integration) do
    create(:accounting_integration,
           organization: organization,
           provider: :tally,
           sync_mode: :realtime_agent,
           status: :connected)
  end

  let(:agent) do
    create(:accounting_agent,
           organization: organization,
           accounting_integration: integration)
  end

  # ─── Associations ─────────────────────────────────────────────────────────
  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:accounting_integration) }
  end

  # ─── Validations ──────────────────────────────────────────────────────────
  describe 'validations' do
    subject { agent }

    it { is_expected.to validate_presence_of(:organization) }
    it { is_expected.to validate_presence_of(:accounting_integration) }
    it { is_expected.to validate_presence_of(:agent_id) }
    it { is_expected.to validate_presence_of(:api_key_digest) }
    it { is_expected.to validate_uniqueness_of(:agent_id) }
  end

  # ─── Callbacks ────────────────────────────────────────────────────────────
  describe 'callbacks' do
    describe 'before_validation' do
      it 'generates agent_id on create' do
        new_agent = AccountingAgent.new(
          organization: organization,
          accounting_integration: integration
        )
        new_agent.valid?
        expect(new_agent.agent_id).to match(/^agent_[a-f0-9-]{36}$/)
      end

      it 'sets registered_at on create' do
        new_agent = AccountingAgent.new(
          organization: organization,
          accounting_integration: integration
        )
        expect(new_agent.registered_at).to be_nil
        new_agent.valid?
        expect(new_agent.registered_at).to be_present
      end
    end
  end

  # ─── Instance Methods ─────────────────────────────────────────────────────
  describe '#online?' do
    it 'returns true when last_heartbeat_at is within 2 minutes and status is online' do
      agent.update!(last_heartbeat_at: 1.minute.ago, status: :online)
      expect(agent.online?).to be true
    end

    it 'returns false when last_heartbeat_at is older than 2 minutes' do
      agent.update!(last_heartbeat_at: 3.minutes.ago, status: :online)
      expect(agent.online?).to be false
    end

    it 'returns false when status is not online' do
      agent.update!(last_heartbeat_at: 1.minute.ago, status: :offline)
      expect(agent.online?).to be false
    end

    it 'returns false when last_heartbeat_at is nil' do
      agent.update!(last_heartbeat_at: nil, status: :online)
      expect(agent.online?).to be false
    end
  end

  describe '#generate_api_key' do
    it 'generates a 64-character hex string' do
      key = agent.generate_api_key
      expect(key).to match(/^[a-f0-9]{64}$/)
    end

    it 'stores a BCrypt digest' do
      key = agent.generate_api_key
      expect(agent.api_key_digest).to be_present
      expect(agent.api_key_digest).not_to eq(key)
      expect(agent.api_key_digest).to start_with('$2a$')
    end
  end

  describe '#verify_api_key' do
    it 'returns true for correct API key' do
      key = agent.generate_api_key
      agent.save!
      expect(agent.verify_api_key(key)).to be true
    end

    it 'returns false for incorrect API key' do
      agent.generate_api_key
      agent.save!
      expect(agent.verify_api_key('wrong_key')).to be false
    end

    it 'returns false when api_key_digest is blank' do
      agent.update_columns(api_key_digest: nil)
      expect(agent.verify_api_key('any_key')).to be false
    end
  end

  describe '#record_heartbeat!' do
    it 'updates last_heartbeat_at and sets status to online' do
      agent.update!(status: :offline, last_heartbeat_at: nil)

      Timecop.freeze do
        agent.record_heartbeat!
        expect(agent.reload.last_heartbeat_at).to be_within(1.second).of(Time.current)
        expect(agent.status).to eq('online')
      end
    end

    it 'updates agent version when provided' do
      agent.record_heartbeat!(agent_version: '1.2.3')
      expect(agent.reload.agent_version).to eq('1.2.3')
    end

    it 'updates os_info and tally_version when provided' do
      agent.record_heartbeat!(
        os_info: 'Windows 11',
        tally_version: 'TallyPrime 2.1'
      )
      expect(agent.reload.os_info).to eq('Windows 11')
      expect(agent.reload.tally_version).to eq('TallyPrime 2.1')
    end
  end

  describe '#mark_offline!' do
    it 'sets status to offline' do
      agent.update!(status: :online)
      agent.mark_offline!
      expect(agent.reload.status).to eq('offline')
    end
  end

  describe '#mark_error!' do
    it 'sets status to error' do
      agent.update!(status: :online)
      agent.mark_error!
      expect(agent.reload.status).to eq('error')
    end
  end

  # ─── Scopes ───────────────────────────────────────────────────────────────
  describe 'scopes' do
    describe '.online' do
      it 'returns agents with recent heartbeat and online status' do
        online_agent = create(:accounting_agent,
                              organization: organization,
                              accounting_integration: integration,
                              last_heartbeat_at: 1.minute.ago,
                              status: :online)
        offline_agent = create(:accounting_agent,
                               organization: organization,
                               accounting_integration: integration,
                               last_heartbeat_at: 3.minutes.ago,
                               status: :online)

        expect(AccountingAgent.online).to include(online_agent)
        expect(AccountingAgent.online).not_to include(offline_agent)
      end
    end

    describe '.offline' do
      it 'returns agents without recent heartbeat' do
        online_agent = create(:accounting_agent,
                              organization: organization,
                              accounting_integration: integration,
                              last_heartbeat_at: 1.minute.ago,
                              status: :online)
        offline_agent = create(:accounting_agent,
                               organization: organization,
                               accounting_integration: integration,
                               last_heartbeat_at: 3.minutes.ago,
                               status: :offline)

        expect(AccountingAgent.offline).to include(offline_agent)
        expect(AccountingAgent.offline).not_to include(online_agent)
      end
    end
  end
end
