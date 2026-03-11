# frozen_string_literal: true

class BankAccountSerializer < ActiveModel::Serializer
  attributes :id, :organization_id, :branch_id, :bank_name, :account_holder_name,
             :masked_account_number, :ifsc_code, :account_type, :currency, :status,
             :created_at, :updated_at

  def masked_account_number
    num = object.account_number.to_s
    return "" if num.blank?
    "#{num[0..1]}#{'*' * [num.length - 4, 0].max}#{num[-2..]}"
  end
end
