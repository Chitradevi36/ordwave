# frozen_string_literal: true

class BankAccountSerializer < BaseSerializer
  def serialize
    {
      id: object.id,
      organization_id: object.organization_id,
      branch_id: object.branch_id,
      bank_name: object.bank_name,
      account_holder_name: object.account_holder_name,
      masked_account_number: masked_account_number,
      ifsc_code: object.ifsc_code,
      account_type: object.account_type,
      currency: object.currency,
      status: object.status,
      created_at: object.created_at,
      updated_at: object.updated_at
    }
  end

  private

  def masked_account_number
    num = object.account_number.to_s
    return "" if num.blank?
    "#{num[0..1]}#{'*' * [num.length - 4, 0].max}#{num[-2..]}"
  end
end
