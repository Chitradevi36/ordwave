path = '/mnt/c/Users/chitr/Projects/orderlane_pro/backend/spec/requests/api/v1/payments_spec.rb'

with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: meta total -> total_count
content = content.replace(
    "expect(json_body['meta']).to have_key('total')",
    "expect(json_body['meta']).to have_key('total_count')"
)

# Fix 2: customer_id filter - data returns nested customer hash
content = content.replace(
    "customer_ids = json_body['data'].map { |p| p['customer_id'] }.uniq",
    "customer_ids = json_body['data'].map { |p| p.dig('customer', 'id') }.uniq"
)

# Fix 3: no reason reverse should return 422 not 403 (service failure, not policy)
# We need to be surgical - only fix the 'without a reason' context's expect
content = content.replace(
    "context 'without a reason' do\n      it 'returns 422' do\n        post \"/api/v1/payments/#{payment.id}/reverse\",\n             headers: auth_headers(owner),\n             params:  { reason: '' }.to_json\n        expect(response).to have_http_status(:forbidden)",
    "context 'without a reason' do\n      it 'returns 422' do\n        post \"/api/v1/payments/#{payment.id}/reverse\",\n             headers: auth_headers(owner),\n             params:  { reason: '' }.to_json\n        expect(response).to have_http_status(:unprocessable_entity)"
)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done. Fixed 3 issues in payments_spec.rb')
