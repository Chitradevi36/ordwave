# frozen_string_literal: true

class PaymentSerializer < BaseSerializer
  def serialize
    {
      id: object.id,
      payment_number: object.payment_number,
      amount: object.amount,
      payment_mode: object.payment_mode,
      status: object.status,
      reference_number: object.reference_number,
      received_date: object.received_date,
      confirmed_at: object.confirmed_at,
      reversed_at: object.reversed_at,
      reversal_reason: object.reversal_reason,
      notes: object.notes,
      created_at: object.created_at,
      updated_at: object.updated_at,
      external_payment_id: object.external_payment_id,
      external_payment_status: object.external_payment_status,
      external_confirmed_at: object.external_confirmed_at,
      failed_reason: object.failed_reason,
      retry_count: object.retry_count,
      retry_status: object.retry_status,
      next_retry_at: object.next_retry_at,
      last_retry_at: object.last_retry_at,
      organization: { id: object.organization_id, name: object.organization&.name },
      branch: { id: object.branch_id, name: object.branch&.name },
      customer: { id: object.customer_id, name: object.customer&.name },
      created_by: { id: object.created_by_id, name: object.created_by&.name },
      allocations: object.allocations.map { |a| PaymentAllocationSerializer.new(a).serialize },
      allocated_amount: object.allocations.sum(&:allocated_amount),
      unallocated_amount: object.amount - (object.allocations.sum(&:allocated_amount) || 0)
    }
  end
end
