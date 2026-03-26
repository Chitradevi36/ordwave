# frozen_string_literal: true

FactoryBot.define do
  factory :accounting_integration do
    association :organization
    provider      { 'tally' }
    sync_mode     { 'batch_export' }
    status        { 'active' }
    enabled       { true }
    host_url      { 'http://localhost:9000' }
    company_name  { 'Test Company' }
  end

  factory :accounting_agent do
    association :organization
    association :accounting_integration
    sequence(:agent_id) { |n| "agent_#{SecureRandom.uuid}" }
    api_key_digest { BCrypt::Password.create('test_api_key_123456') }
    status             { 'online' }
    last_heartbeat_at  { 1.minute.ago }
    registered_at      { 1.hour.ago }
    agent_version      { '1.0.0' }
    os_info            { 'Windows 11' }
    tally_version      { 'TallyPrime 2.1' }
  end

  factory :accounting_sync_record do
    association :organization
    association :accounting_integration
    sync_type      { 'voucher' }
    source_model   { 'SalesInvoice' }
    source_id      { 1 }
    status         { 'pending' }
    attempt_count  { 0 }
    payload        { { invoice_number: 'INV-001' }.to_json }
    response_body  { '<VOUCHER><VOUCHERTYPENAME>Sales</VOUCHERTYPENAME></VOUCHER>' }
  end
end
