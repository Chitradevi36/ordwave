require 'rails_helper'

RSpec.describe Returns::Cancel, type: :service do
  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }
  let(:customer){ create(:customer, organization: org) }
  let(:actor)   { create(:user) }

  def call(return_request:, reason: 'Customer changed their mind')
    described_class.call(actor: actor, return_request: return_request, reason: reason)
  end

  shared_examples 'a cancellable return' do |initial_status|
    let(:return_request) do
      create(:return_request, organization: org, branch: branch, customer: customer,
             created_by: actor, status: initial_status)
    end

    it 'returns success' do
      expect(call(return_request: return_request).success?).to be true
    end

    it 'transitions the return request to cancelled' do
      call(return_request: return_request)
      expect(return_request.reload.status).to eq('cancelled')
    end

    it 'records the cancellation reason' do
      call(return_request: return_request, reason: 'Duplicate entry')
      expect(return_request.reload.cancellation_reason).to eq('Duplicate entry')
    end

    it 'sets cancelled_at timestamp' do
      freeze_time = Time.current
      travel_to(freeze_time) { call(return_request: return_request) }
      expect(return_request.reload.cancelled_at).to be_within(1.second).of(freeze_time)
    end

    it 'creates an audit log entry' do
      expect { call(return_request: return_request) }.to change(AuditLog, :count).by(1)
    end

    it 'records audit action as return_cancelled' do
      call(return_request: return_request)
      expect(AuditLog.last.action).to eq('return_cancelled')
    end
  end

  describe '.call' do
    context 'from draft status' do
      include_examples 'a cancellable return', 'draft'
    end

    context 'from submitted status' do
      include_examples 'a cancellable return', 'submitted'
    end

    context 'when reason is blank' do
      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'draft')
      end

      it 'returns failure' do
        result = call(return_request: return_request, reason: '')
        expect(result.success?).to be false
        expect(result.errors.join).to match(/reason is required/i)
      end

      it 'does not change the status' do
        call(return_request: return_request, reason: '')
        expect(return_request.reload.status).to eq('draft')
      end
    end

    context 'after QC has been completed (qc_completed)' do
      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'qc_completed')
      end

      it 'returns failure' do
        result = call(return_request: return_request)
        expect(result.success?).to be false
        expect(result.errors.join).to match(/cannot cancel/i)
      end

      it 'does not change the status' do
        call(return_request: return_request)
        expect(return_request.reload.status).to eq('qc_completed')
      end
    end

    context 'when QC is in progress (qc_in_progress)' do
      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'qc_in_progress')
      end

      it 'returns failure (inventory may have been partially posted)' do
        result = call(return_request: return_request)
        expect(result.success?).to be false
      end
    end

    context 'when already cancelled' do
      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'cancelled',
               cancellation_reason: 'Original reason')
      end

      it 'returns failure' do
        result = call(return_request: return_request, reason: 'Another reason')
        expect(result.success?).to be false
      end
    end

    context 'when credit note has been issued (credit_note_issued)' do
      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'credit_note_issued')
      end

      it 'returns failure' do
        result = call(return_request: return_request)
        expect(result.success?).to be false
      end
    end
  end
end
