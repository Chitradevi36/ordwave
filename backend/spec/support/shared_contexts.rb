# frozen_string_literal: true

# Shared contexts for common test setups.
# Usage: `include_context "with_authenticated_user"` or `it_behaves_like "a paginated endpoint"`

RSpec.shared_context "with_authenticated_user" do
  let(:org)      { create(:organization) }
  let(:owner)    { create(:user, organization: org, role: :owner) }
  let(:headers)  { auth_headers(owner) }
end

RSpec.shared_context "with_admin_user" do
  let(:org)      { create(:organization) }
  let(:admin)    { create(:user, organization: org, role: :admin) }
  let(:headers)  { auth_headers(admin) }
end

RSpec.shared_examples "a paginated endpoint" do
  it "returns pagination metadata" do
    expect(json_body).to include("meta")
    meta = json_body["meta"]
    expect(meta).to include("current_page", "total_pages", "total_count")
  end
end

RSpec.shared_examples "an unauthorized endpoint" do
  it "returns 401 without auth headers" do
    make_request({})
    expect(response).to have_http_status(:unauthorized)
  end
end
