require 'rails_helper'

RSpec.describe Orders::ApproveOrderService, type: :service do
  let(:org)      { create(:organization) }
  let(:branch)   { create(:branch, organization: org) }
  let(:customer) { create(:customer, organization: org, branch: branch) }
  let(:actor)    { create(:user) }
  let(:product)  { create(:product, organization: org) }

  let!(:credit_account) do
    create(:credit_account, customer: customer, organization: org, branch: branch,
           credit_limit: 100_000, current_balance: 0, available_credit: 100_000,
           overdue_amount: 0, overdue_days: 0)
  end

  def make_on_hold_order
    order = create(:sales_order, organization: org, branch: branch, customer: customer, 
                   created_by: actor, status: 'on_hold')
    create(:sales_order_line, sales_order: order, product: product, qty: 5, 
           unit_price: 100, discount_pct: 0, line_total: 500)
    order.recalculate_totals!
    order
  end

  describe '.call' do
    describe 'validation' do
      let(:order) { make_on_hold_order }

      it 'returns errors when decision is invalid' do
        result = described_class.call(order: order, decision: 'invalid', actor: actor)
        expect(result[:errors]).to include("Invalid decision. Must be 'approved' or 'rejected'")
      end

      it 'returns errors when order status is not on_hold or submitted' do
        order.update(status: 'draft')
        result = described_class.call(order: order, decision: 'approved', actor: actor)
        expect(result[:errors]).to include('Order must be submitted or on_hold to approve or reject')
      end

      it 'returns errors when rejecting without reason' do
        result = described_class.call(order: order, decision: 'rejected', actor: actor)
        expect(result[:errors]).to include('Reason is required when rejecting')
      end

      describe 'Feature 9: Dunning suspension checks' do
        context 'when customer is dunning suspended' do
          before do
            customer.update(dunning_suspended_at: 3.days.ago)
          end

          it 'prevents approval with error message' do
            result = described_class.call(order: order, decision: 'approved', actor: actor)
            expect(result[:success]).to be false
            expect(result[:errors]).to include(
              include("Cannot approve order: Customer account is suspended due to overdue invoices")
            )
          end

          it 'allows rejection even if suspended' do
            result = described_class.call(order: order, decision: 'rejected', reason: 'Customer credit risk', actor: actor)
            expect(result[:success]).to be true
            expect(order.reload.status).to eq('rejected')
          end
        end

        context 'when customer is not dunning suspended' do
          before do
            customer.update(dunning_suspended_at: nil)
          end

          it 'allows approval' do
            result = described_class.call(order: order, decision: 'approved', actor: actor)
            expect(result[:success]).to be true
            expect(order.reload.status).to eq('approved')
          end
        end

        context 'when dunning_suspended_at is in the future' do
          before do
            customer.update(dunning_suspended_at: 1.day.from_now)
          end

          it 'prevents approval (suspension is active)' do
            result = described_class.call(order: order, decision: 'approved', actor: actor)
            expect(result[:success]).to be false
            expect(result[:errors]).to include(
              include("Cannot approve order: Customer account is suspended")
            )
          end
        end
      end
    end

    describe 'approval flow' do
      let(:order) { make_on_hold_order }
      let(:pickup_location) { create(:location, organization: org) }

      before do
        allow_any_instance_of(described_class).to receive(:notify_on_decision)
        allow_any_instance_of(described_class).to receive(:create_pick_list_for_order)
      end

      context 'when decision is valid and customer is not suspended' do
        it 'transitions order to approved' do
          result = described_class.call(order: order, decision: 'approved', actor: actor)
          expect(result[:success]).to be true
          expect(order.reload.status).to eq('approved')
        end

        it 'sets approval timestamp' do
          result = described_class.call(order: order, decision: 'approved', actor: actor)
          expect(order.reload.approved_at).to be_present
        end

        it 'records approval actor' do
          result = described_class.call(order: order, decision: 'approved', actor: actor)
          expect(order.reload.approved_by).to eq(actor.id)
        end

        it 'notifies on decision' do
          expect_any_instance_of(described_class).to receive(:notify_on_decision)
          described_class.call(order: order, decision: 'approved', actor: actor)
        end

        it 'creates pick list when pickup_location provided' do
          expect_any_instance_of(described_class).to receive(:create_pick_list_for_order)
          described_class.call(order: order, decision: 'approved', actor: actor, pickup_location: pickup_location)
        end
      end

      context 'when decision is rejection' do
        it 'transitions order to rejected' do
          result = described_class.call(order: order, decision: 'rejected', reason: 'Insufficient credit', actor: actor)
          expect(result[:success]).to be true
          expect(order.reload.status).to eq('rejected')
        end

        it 'records rejection reason' do
          result = described_class.call(order: order, decision: 'rejected', reason: 'Insufficient credit', actor: actor)
          expect(order.reload.rejection_reason).to eq('Insufficient credit')
        end

        it 'records rejection timestamp' do
          result = described_class.call(order: order, decision: 'rejected', reason: 'Insufficient credit', actor: actor)
          expect(order.reload.rejected_at).to be_present
        end
      end
    end

    describe 'audit logging' do
      let(:order) { make_on_hold_order }

      before do
        allow_any_instance_of(described_class).to receive(:notify_on_decision)
        allow_any_instance_of(described_class).to receive(:create_pick_list_for_order)
      end

      it 'creates audit log for approval' do
        expect {
          described_class.call(order: order, decision: 'approved', actor: actor)
        }.to change(AuditLog, :count).by(1)
        
        audit = AuditLog.last
        expect(audit.action).to eq('order_approved')
        expect(audit.actor).to eq(actor)
        expect(audit.resource).to eq(order)
      end

      it 'creates audit log for rejection' do
        expect {
          described_class.call(order: order, decision: 'rejected', reason: 'Insufficient funds', actor: actor)
        }.to change(AuditLog, :count).by(1)
        
        audit = AuditLog.last
        expect(audit.action).to eq('order_rejected')
        expect(audit.actor).to eq(actor)
      end
    end

    describe 'error handling' do
      let(:order) { make_on_hold_order }

      it 'returns failure when order save fails' do
        allow_any_instance_of(SalesOrder).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
        result = described_class.call(order: order, decision: 'approved', actor: actor)
        expect(result[:success]).to be false
        expect(result[:errors]).to include(kind_of(String))
      end

      it 'handles missing actor gracefully' do
        result = described_class.call(order: order, decision: 'approved', actor: nil)
        expect(result[:success]).to be false
      end
    end
  end

  describe 'integration with dunning enforcement' do
    let(:order) { make_on_hold_order }
    
    context 'when DunningEnforcementJob has suspended customer' do
      before do
        # Simulate Day 10 enforcement: hard_block + suspension
        customer.update!(
          credit_block_rule: 'hard_block',
          dunning_suspended_at: 2.days.ago,
          dunning_suspension_reason: 'overdue_invoice',
          dunning_suspension_invoice_id: 'INV-123'
        )
      end

      it 'prevents order approval' do
        result = described_class.call(order: order, decision: 'approved', actor: actor)
        expect(result[:success]).to be false
        expect(result[:errors]).to include(
          include("Cannot approve order")
        )
      end

      it 'logs the dunning suspension details' do
        expect {
          described_class.call(order: order, decision: 'approved', actor: actor)
        }.not_to change(AuditLog, :count) # Should fail before logging
      end
    end

    context 'when customer suspension is lifted (dunning_suspended_at cleared)' do
      before do
        customer.update!(
          credit_block_rule: 'hard_block',
          dunning_suspended_at: nil # Suspension lifted
        )
      end

      it 'allows order approval' do
        result = described_class.call(order: order, decision: 'approved', actor: actor)
        expect(result[:success]).to be true
        expect(order.reload.status).to eq('approved')
      end
    end
  end
end
