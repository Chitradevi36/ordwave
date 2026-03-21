require 'rails_helper'

RSpec.describe DunningEnforcementJob, type: :job do
  let(:org) { create(:organization) }
  let(:customer1) { create(:customer, organization: org) }
  let(:customer2) { create(:customer, organization: org) }
  let(:customer3) { create(:customer, organization: org) }

  describe '#perform' do
    context 'with no dunning data' do
      it 'completes without errors' do
        expect {
          described_class.perform_now
        }.not_to raise_error
      end

      it 'does not suspend any customers' do
        described_class.perform_now
        expect(Customer.where.not(dunning_suspended_at: nil)).not_to exist
      end
    end

    context 'Day 5 enforcement: soft_block' do
      before do
        create(:dunning_sequence,
               customer: customer1,
               organization: org,
               last_email_sent_at: 5.days.ago,
               enforcement_level: 'day_5')
      end

      it 'sets credit_block_rule to soft_block' do
        described_class.perform_now
        expect(customer1.reload.credit_block_rule).to eq('soft_block')
      end

      it 'does not set dunning_suspended_at for soft block' do
        described_class.perform_now
        expect(customer1.reload.dunning_suspended_at).to be_nil
      end

      it 'sends notification to finance team' do
        expect {
          described_class.perform_now
        }.to change { Notification.where(user: nil).count }.by(1) # Broadcast to finance
      end

      it 'marks enforcement as applied in dunning_sequence' do
        seq = create(:dunning_sequence,
                     customer: customer1,
                     organization: org,
                     last_email_sent_at: 5.days.ago,
                     enforcement_level: 'day_5')
        
        described_class.perform_now
        expect(seq.reload.day_5_enforcement_applied_at).to be_present
      end

      it 'is idempotent (running twice applies once)' do
        described_class.perform_now
        original_updated = customer1.reload.updated_at
        
        # Run again
        described_class.perform_now
        expect(customer1.reload.credit_block_rule).to eq('soft_block')
        expect(customer1.updated_at).to eq(original_updated)
      end
    end

    context 'Day 10 enforcement: hard_block + suspension' do
      before do
        create(:dunning_sequence,
               customer: customer2,
               organization: org,
               last_email_sent_at: 10.days.ago,
               enforcement_level: 'day_10')
      end

      it 'sets credit_block_rule to hard_block' do
        described_class.perform_now
        expect(customer2.reload.credit_block_rule).to eq('hard_block')
      end

      it 'sets dunning_suspended_at timestamp' do
        described_class.perform_now
        expect(customer2.reload.dunning_suspended_at).to be_present
        expect(customer2.reload.dunning_suspended_at).to be_within(1.minute).of(Time.current)
      end

      it 'records suspension reason' do
        dunning_seq = create(:dunning_sequence,
                            customer: customer2,
                            organization: org,
                            last_email_sent_at: 10.days.ago,
                            enforcement_level: 'day_10',
                            invoice_id: 'INV-456')
        
        described_class.perform_now
        expect(customer2.reload.dunning_suspension_reason).to eq('overdue_invoice')
      end

      it 'records associated invoice ID' do
        dunning_seq = create(:dunning_sequence,
                            customer: customer2,
                            organization: org,
                            last_email_sent_at: 10.days.ago,
                            enforcement_level: 'day_10',
                            invoice_id: 'INV-456')
        
        described_class.perform_now
        expect(customer2.reload.dunning_suspension_invoice_id).to eq('INV-456')
      end

      it 'sends URGENT alert to finance team' do
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        allow(TwilioClient).to receive(:send_sms).and_return(true)

        finance_manager = create(:user, organization: org, role: 'finance')

        described_class.perform_now
        
        # Should have attempted SMS alert
        expect(TwilioClient).to have_received(:send_sms).at_least(:once)
      end

      it 'blocks customer from placing new orders' do
        user = create(:customer_user, customer: customer2)
        order = create(:sales_order, customer: customer2, status: 'on_hold')

        described_class.perform_now

        result = Orders::ApproveOrderService.call(
          order: order,
          decision: 'approved',
          actor: create(:user)
        )
        expect(result[:success]).to be false
        expect(result[:errors]).to include(
          include("Cannot approve order: Customer account is suspended")
        )
      end

      it 'records enforcement application timestamp' do
        seq = create(:dunning_sequence,
                     customer: customer2,
                     organization: org,
                     last_email_sent_at: 10.days.ago,
                     enforcement_level: 'day_10')
        
        described_class.perform_now
        expect(seq.reload.day_10_enforcement_applied_at).to be_present
      end
    end

    context 'Day 15 enforcement: escalation' do
      before do
        create(:dunning_sequence,
               customer: customer3,
               organization: org,
               last_email_sent_at: 15.days.ago,
               enforcement_level: 'day_15')
      end

      it 'maintains hard_block state' do
        described_class.perform_now
        expect(customer3.reload.credit_block_rule).to eq('hard_block')
      end

      it 'keeps suspension active' do
        described_class.perform_now
        expect(customer3.reload.dunning_suspended_at).to be_present
      end

      it 'sends escalation alert to operations managers' do
        ops_manager = create(:user, organization: org, role: 'operations')
        
        allow(TwilioClient).to receive(:enabled?).and_return(true)
        allow(TwilioClient).to receive(:send_sms).and_return(true)

        described_class.perform_now
        
        expect(TwilioClient).to have_received(:send_sms).with(
          anything,
          include("ESCALATION"),
          anything
        )
      end

      it 'creates escalation audit log' do
        expect {
          described_class.perform_now
        }.to change(AuditLog, :count).by(1)
        
        audit = AuditLog.last
        expect(audit.action).to include('day_15_escalation')
      end

      it 'records enforcement application timestamp' do
        seq = create(:dunning_sequence,
                     customer: customer3,
                     organization: org,
                     last_email_sent_at: 15.days.ago,
                     enforcement_level: 'day_15')
        
        described_class.perform_now
        expect(seq.reload.day_15_enforcement_applied_at).to be_present
      end
    end

    context 'multiple customers at different enforcement levels' do
      before do
        create(:dunning_sequence,
               customer: customer1,
               organization: org,
               last_email_sent_at: 5.days.ago,
               enforcement_level: 'day_5')
        
        create(:dunning_sequence,
               customer: customer2,
               organization: org,
               last_email_sent_at: 10.days.ago,
               enforcement_level: 'day_10')
        
        create(:dunning_sequence,
               customer: customer3,
               organization: org,
               last_email_sent_at: 15.days.ago,
               enforcement_level: 'day_15')
      end

      it 'applies correct enforcement to each customer' do
        described_class.perform_now

        expect(customer1.reload.credit_block_rule).to eq('soft_block')
        expect(customer1.reload.dunning_suspended_at).to be_nil

        expect(customer2.reload.credit_block_rule).to eq('hard_block')
        expect(customer2.reload.dunning_suspended_at).to be_present

        expect(customer3.reload.credit_block_rule).to eq('hard_block')
        expect(customer3.reload.dunning_suspended_at).to be_present
      end
    end

    context 'enforcement reversal' do
      before do
        customer1.update(
          credit_block_rule: 'soft_block',
          dunning_suspended_at: 10.days.ago,
          dunning_suspension_reason: 'overdue_invoice'
        )
      end

      it 'clears suspension when dunning_suspended_at is manually cleared' do
        customer1.update(dunning_suspended_at: nil)
        
        expect(customer1.reload.dunning_suspended_at).to be_nil
        expect(customer1.credit_block_rule).to eq('soft_block') # Soft block remains until cleared
      end

      it 'allows order approval after suspension clearance' do
        customer1.update(dunning_suspended_at: nil, credit_block_rule: 'none')
        order = create(:sales_order, customer: customer1, status: 'on_hold')

        result = Orders::ApproveOrderService.call(
          order: order,
          decision: 'approved',
          actor: create(:user)
        )
        expect(result[:success]).to be true
      end
    end

    context 'already suspended customers' do
      before do
        customer1.update(
          dunning_suspended_at: 5.days.ago,
          credit_block_rule: 'hard_block'
        )
      end

      it 'does not re-suspend already suspended customers' do
        create(:dunning_sequence,
               customer: customer1,
               organization: org,
               last_email_sent_at: 10.days.ago,
               enforcement_level: 'day_10')
        
        original_time = customer1.dunning_suspended_at
        described_class.perform_now
        
        expect(customer1.reload.dunning_suspended_at).to eq(original_time)
      end

      it "skips enforcement for 'Day 5' with new sequence" do
        create(:dunning_sequence,
               customer: customer1,
               organization: org,
               last_email_sent_at: 5.days.ago,
               enforcement_level: 'day_5')
        
        described_class.perform_now
        
        # Hard block + suspended should not downgrade to soft block
        expect(customer1.reload.credit_block_rule).to eq('hard_block')
        expect(customer1.dunning_suspended_at).to be_present
      end
    end
  end

  describe 'integration with DunningSequenceJob' do
    it 'works correctly when run after DunningSequenceJob' do
      # Day 1: Send first email
      create(:dunning_sequence,
             customer: customer1,
             organization: org,
             last_email_sent_at: 1.day.ago,
             enforcement_level: 'day_1')

      DunningSequenceJob.perform_now
      expect(customer1.reload.credit_block_rule).to eq('none') # No enforcement on Day 1

      # Day 10: Apply enforcement
      dunning_seq = customer1.dunning_sequences.first
      dunning_seq.update(last_email_sent_at: 10.days.ago, enforcement_level: 'day_10')

      DunningEnforcementJob.perform_now

      expect(customer1.reload.credit_block_rule).to eq('hard_block')
      expect(customer1.dunning_suspended_at).to be_present
    end
  end
end
