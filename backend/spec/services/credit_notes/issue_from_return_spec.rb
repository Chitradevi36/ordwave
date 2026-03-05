require 'rails_helper'

RSpec.describe CreditNotes::IssueFromReturn, type: :service do
  let(:org)     { create(:organization) }
  let(:branch)  { create(:branch, organization: org) }
  let(:customer){ create(:customer, organization: org) }
  let(:actor)   { create(:user) }
  let(:product) { create(:product, organization: org) }

  # Stub GST calculator to return a predictable result regardless of branch/customer state codes
  let(:gst_result) do
    Struct.new(:intra_state, :cgst_rate, :sgst_rate, :igst_rate,
               :cgst_amount, :sgst_amount, :igst_amount, :total_tax).new(
      true, 9, 9, 0, 9.0, 9.0, 0.0, 18.0
    )
  end

  before do
    allow(Gst::GstCalculator).to receive(:calculate).and_return(gst_result)
  end

  # A return_request already in qc_completed with a line that has a resalable QC item
  let(:return_request) do
    create(:return_request, organization: org, branch: branch, customer: customer,
           created_by: actor, status: 'qc_completed')
  end

  let(:return_line) do
    create(:return_line,
           return_request:      return_request,
           product:             product,
           qty_reported:        5,
           qty_accepted:        3,
           unit_price_snapshot: 100.0,
           gst_rate_snapshot:   18.0,
           hsn_code_snapshot:   '12345678')
  end

  before do
    # Create QC item asserting 3 resalable units
    create(:return_qc_item,
           return_line:    return_line,
           qc_by:          actor,
           qty_resalable:  3,
           qty_damaged:    1,
           qty_expired:    0,
           condition_final: 'mixed')
  end

  def call(**opts)
    described_class.call(actor: actor, return_request: return_request, **opts)
  end

  describe '.call' do
    context 'with a valid qc_completed return' do
      it 'returns success' do
        expect(call.success?).to be true
      end

      it 'creates a CreditNote record' do
        expect { call }.to change(CreditNote, :count).by(1)
      end

      it 'creates CreditNoteLines for creditable lines' do
        expect { call }.to change(CreditNoteLine, :count).by(1)
      end

      it 'sets the credit note status to issued immediately' do
        result = call
        expect(result.credit_note.status).to eq('issued')
      end

      it 'assigns a credit_note_number in CN-XXXX-XXXXXX format' do
        result = call
        expect(result.credit_note.credit_note_number).to match(/\ACN-\d{4}-\d{6}\z/)
      end

      it 'transitions the return request to credit_note_issued' do
        call
        expect(return_request.reload.status).to eq('credit_note_issued')
      end

      it 'creates an audit log entry' do
        expect { call }.to change(AuditLog, :count).by(1)
      end

      it 'sets audit log action to credit_note_issued' do
        call
        expect(AuditLog.last.action).to eq('credit_note_issued')
      end

      context 'price snapshot is used (not current product price)' do
        before { product.update_columns(selling_price: 999.0) }

        it 'uses unit_price_snapshot from the return line, not current product price' do
          result = call
          expect(result.credit_note.lines.first.unit_price.to_d).to eq(100.0.to_d)
        end
      end

      context 'GST snapshot is used' do
        it 'passes gst_rate_snapshot to the GST calculator' do
          call
          expect(Gst::GstCalculator).to have_received(:calculate).with(
            hash_including(gst_rate: 18.0.to_d)
          )
        end

        it 'records the tax_amount returned by the GST calculator' do
          result = call
          line = result.credit_note.lines.first
          # 3 units × 100 = 300 taxable, 18.0 tax per GstCalculator stub
          expect(line.tax_amount.to_d).to eq(18.0.to_d)
        end

        it 'computes line_total as taxable + tax' do
          result = call
          line = result.credit_note.lines.first
          # 300 taxable + 18 tax = 318
          expect(line.line_total.to_d).to eq(318.0.to_d)
        end
      end

      it 'records the hsn_code_snapshot on the credit note line' do
        result = call
        expect(result.credit_note.lines.first.hsn_code).to eq('12345678')
      end

      it 'recalculates CreditNote totals' do
        result = call
        cn = result.credit_note
        expect(cn.subtotal.to_d).to eq(300.0.to_d)
        expect(cn.tax_total.to_d).to eq(18.0.to_d)
        expect(cn.total.to_d).to eq(318.0.to_d)
      end
    end

    context 'when no creditable (resalable) lines exist' do
      before { return_line.qc_item.update!(qty_resalable: 0, qty_damaged: 5) }

      it 'returns failure' do
        result = call
        expect(result.success?).to be false
        expect(result.errors.join).to match(/no resalable/i)
      end

      it 'does not create a CreditNote' do
        expect { call }.not_to change(CreditNote, :count)
      end

      it 'does not transition the return request' do
        call
        expect(return_request.reload.status).to eq('qc_completed')
      end
    end

    context 'when a credit note already exists for this return' do
      before { call }  # issue once successfully

      it 'returns failure on second call' do
        result = call
        expect(result.success?).to be false
        expect(result.errors.join).to match(/already exists/i)
      end

      it 'does not create a duplicate CreditNote' do
        expect { call }.not_to change(CreditNote, :count)
      end
    end

    context 'when return_request is not in qc_completed state' do
      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'qc_in_progress')
      end

      it 'returns failure' do
        result = call
        expect(result.success?).to be false
        expect(result.errors.join).to match(/qc is completed/i)
      end
    end

    context 'with source_type order — resolves associated sales order' do
      let(:sales_order) do
        create(:sales_order, organization: org, branch: branch, customer: customer,
               created_by: actor)
      end

      let(:return_request) do
        create(:return_request, organization: org, branch: branch, customer: customer,
               created_by: actor, status: 'qc_completed',
               source_type: 'order', source_id: sales_order.id)
      end

      it 'links the credit note to the originating sales order' do
        result = call
        expect(result.credit_note.sales_order).to eq(sales_order)
      end
    end

    context 'with notes provided' do
      it 'records the notes on the credit note' do
        result = call(notes: 'Damaged goods returned per policy')
        expect(result.credit_note.notes).to eq('Damaged goods returned per policy')
      end
    end
  end
end
