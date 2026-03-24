# Document Generation - Authorization & Security Guide

## Overview

This guide covers authorization policies, access control, and security measures for the document generation system.

## Authorization Framework

The document generation system uses **Pundit** for fine-grained authorization.

### Installation

```ruby
# backend/Gemfile
gem 'pundit', '~> 2.3'
```

```bash
bundle install
rails generate pundit:install
```

## Authorization Policies

### DocumentPolicy Class

Create `backend/app/policies/document_policy.rb`:

```ruby
class DocumentPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      # Users can only see documents from their organization
      scope.where(organization_id: user.organization_id)
        .where(archived_at: nil)
    end

    def resolve_with_archived
      scope.where(organization_id: user.organization_id)
    end
  end

  def index?
    # All authenticated users in organization can list documents
    user.organization_id == record.organization_id
  end

  def show?
    # Can view if from same org and not archived, OR if own org admin
    user&.organization_id == record&.organization_id &&
      (record.archived_at.nil? || admin?)
  end

  def generate?
    # Document generation restricted to:
    # - Organization admins
    # - Finance team members
    # - Billing managers
    admin? || finance_team? || billing_manager?
  end

  def batch_generate?
    # Only admins and finance heads can batch generate
    admin? || finance_head?
  end

  def download?
    # Can download if:
    # - User is from same organization
    # - Document is not archived OR user is admin
    user&.organization_id == record&.organization_id &&
      (record.archived_at.nil? || admin?)
  end

  def regenerate?
    # Can regenerate if:
    # - User is admin OR finance team
    # - Document is not archived
    # - Not regenerated more than X times in Y hours (rate limit)
    (admin? || finance_team?) &&
      record.archived_at.nil? &&
      !rate_limited?
  end

  def archive?
    # Can archive if:
    # - User is admin OR document owner
    # - Document exists and is active
    (admin? || document_owner?) && record.archived_at.nil?
  end

  def statistics?
    # Organization admins can view statistics
    admin?
  end

  private

  def admin?
    user&.admin? && user&.organization_id == record&.organization_id
  end

  def finance_team?
    user&.organization_id == record&.organization_id &&
      user&.roles&.include?('finance')
  end

  def finance_head?
    user&.organization_id == record&.organization_id &&
      user&.roles&.include?('finance_head')
  end

  def billing_manager?
    user&.organization_id == record&.organization_id &&
      user&.roles&.include?('billing_manager')
  end

  def document_owner?
    user&.id == record&.generated_by_user_id
  end

  def rate_limited?
    # Prevent regenerating same document more than 5 times per day
    Document.where(id: record.id)
      .where('updated_at > ?', 24.hours.ago)
      .count > 5
  end
end
```

## Role-Based Access Control

### User Roles Configuration

```ruby
# User model should include roles
class User < ApplicationRecord
  has_many :roles, class_name: 'UserRole'
  
  # Convenience methods
  def admin?
    roles.exists?(role_type: 'admin')
  end

  def can_generate_documents?
    admin? || roles.exists?(role_type: ['finance', 'billing_manager'])
  end

  def can_batch_generate?
    admin? || roles.exists?(role_type: 'finance_head')
  end
end

class UserRole < ApplicationRecord
  belongs_to :user
  
  enum role_type: { 
    admin: 'admin',
    finance: 'finance',
    finance_head: 'finance_head',
    billing_manager: 'billing_manager',
    logistics: 'logistics',
    view_only: 'view_only'
  }
end
```

### Role Definitions

| Role | Generate | Batch Generate | Download | Regenerate | Archive | View |
|------|----------|----------------|----------|------------|---------|------|
| Admin | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Finance Head | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Finance | ✅ | ❌ | ✅ | ✅ | ❌ | ✅ |
| Billing Manager | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| Logistics | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| View Only | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |

## Controller Integration

### Apply Policies in DocumentsController

```ruby
# backend/app/controllers/api/v1/documents_controller.rb
class Api::V1::DocumentsController < ApplicationController
  include Pundit::Authorization
  
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  before_action :authenticate_user!
  before_action :set_organization
  before_action :set_document, only: %i[show download regenerate archive]

  # List documents
  def index
    authorize Document.new(organization_id: @organization.id)
    
    @documents = policy_scope(Document)
      .where(organization_id: @organization.id)
      .apply_filters(filter_params)
      .paginate(page: params[:page], per_page: 20)
    
    render_success(@documents.map { |d| serialize_document(d) })
  end

  # Get single document
  def show
    authorize @document
    render_success(serialize_document(@document))
  end

  # Generate single document
  def generate
    authorize Document.new(
      organization_id: current_user.organization_id
    ), :generate?

    service = DocumentGeneratorService.new
    document_data = generate_params.merge(
      organization_id: current_user.organization_id,
      generated_by_user_id: current_user.id
    )

    begin
      document = service.generate_and_save(
        generate_params[:type],
        generate_params[:data],
        current_user.organization_id,
        metadata: {
          requested_by: current_user.email,
          requested_at: Time.current,
          user_ip: request.remote_ip
        }
      )
      render_created(serialize_document(document))
    rescue DocumentGeneratorService::TemplateNotFoundError => e
      render_errors("Template not found: #{e.message}", :unprocessable_entity)
    rescue => e
      render_errors("Generation failed: #{e.message}", :internal_server_error)
    end
  end

  # Batch generate documents
  def batch_generate
    authorize Document.new(
      organization_id: current_user.organization_id
    ), :batch_generate?

    service = DocumentGeneratorService.new
    documents_data = batch_generate_params[:documents]

    results = {
      generated: [],
      failed: []
    }

    documents_data.each do |doc_data|
      begin
        document = service.generate_and_save(
          batch_generate_params[:type],
          doc_data[:data],
          current_user.organization_id,
          metadata: doc_data[:metadata] || {}
        )
        results[:generated] << serialize_document(document)
      rescue => e
        results[:failed] << {
          data: doc_data,
          error: e.message
        }
      end
    end

    render_created(results)
  end

  # Download document
  def download
    authorize @document, :download?
    
    send_data(
      @document.content,
      filename: @document.filename,
      type: 'application/pdf',
      disposition: 'attachment'
    )
  end

  # Regenerate document
  def regenerate
    authorize @document, :regenerate?

    service = DocumentGeneratorService.new
    
    begin
      updated_document = service.regenerate(
        @document.id,
        regenerate_params[:data]
      )
      render_success(serialize_document(updated_document))
    rescue => e
      render_errors("Regeneration failed: #{e.message}", :internal_server_error)
    end
  end

  # Archive document
  def archive
    authorize @document, :archive?
    
    @document.archive!
    render_success(serialize_document(@document))
  end

  # Get organization statistics
  def statistics
    authorize Document.new(
      organization_id: current_user.organization_id
    ), :statistics?

    stats = Document.statistics_for_org(current_user.organization_id)
    render_success(stats)
  end

  private

  def set_organization
    @organization = current_user.organization
  end

  def set_document
    @document = Document.find(params[:id])
    
    unless @document.organization_id == current_user.organization_id
      render_not_found("Document not found")
    end
  end

  def serialize_document(doc)
    {
      id: doc.id,
      type: doc.document_type,
      filename: doc.filename,
      size: doc.size_bytes,
      size_formatted: doc.size_formatted,
      status: doc.status,
      created_at: doc.created_at,
      archived_at: doc.archived_at,
      download_url: api_v1_document_download_url(doc),
      metadata: doc.metadata
    }
  end

  def generate_params
    params.require(:document).permit(:type, data: {})
  end

  def batch_generate_params
    params.require(:batch).permit(:type, documents: [:data, :metadata])
  end

  def regenerate_params
    params.require(:document).permit(data: {})
  end

  def filter_params
    params.permit(:type, :status, :start_date, :end_date, :search)
  end

  def user_not_authorized
    render_errors(
      "Not authorized to perform this action",
      :forbidden
    )
  end
end
```

## Security Best Practices

### 1. Data Validation

```ruby
# In Document model
validates :document_type, inclusion: { 
  in: %w(invoice waybill ewaybill delivery_receipt credit_note),
  message: "%{value} is not a valid document type" 
}

validates :size_bytes, numericality: { 
  less_than_or_equal_to: 50.megabytes 
}

validates :filename, presence: true, 
  uniqueness: { scope: :organization_id }
```

### 2. Rate Limiting

```ruby
# Add to Gemfile
gem 'redis-rails'

# In DocumentsController
before_action :check_rate_limit, only: %i[generate batch_generate regenerate]

def check_rate_limit
  rate_limiter_key = "documents:generate:#{current_user.id}"
  
  if Rails.cache.increment(rate_limiter_key, 1, expires_in: 1.hour) > 100
    render_errors("Rate limit exceeded. Max 100 generations per hour", :too_many_requests)
  end
end
```

### 3. File Hash Verification

```ruby
# In Document model
before_save :calculate_file_hash

def calculate_file_hash
  return unless content_changed?
  self.file_hash = Digest::SHA256.hexdigest(content)
end

# Verify downloaded content
def verify_integrity
  Digest::SHA256.hexdigest(content) == file_hash
end
```

### 4. Audit Logging

```ruby
# In Document model
after_create :log_creation
after_update :log_update
after_destroy :log_deletion

def log_creation
  AuditLog.create!(
    action: 'document_created',
    organization_id: organization_id,
    user_id: generated_by_user_id,
    resource_type: 'Document',
    resource_id: id,
    changes: attributes,
    ip_address: metadata['user_ip'],
    timestamp: created_at
  )
end

def log_update
  AuditLog.create!(
    action: 'document_updated',
    organization_id: organization_id,
    user_id: nil,
    resource_type: 'Document',
    resource_id: id,
    changes: saved_changes,
    timestamp: Time.current
  )
end
```

### 5. GDPR Compliance

```ruby
# Auto-cleanup old documents
class DocumentsCleanupJob
  include Sidekiq::Worker

  sidekiq_options retry: 3

  def perform
    # Delete archived documents older than 90 days
    Document.where('archived_at < ?', 90.days.ago).delete_all
    
    # Delete sensitive metadata older than 1 year
    Document.where('created_at < ?', 1.year.ago)
      .update_all(metadata: {})
  end
end

# Schedule with sidekiq-cron
# Every day at 2 AM
{ 'DocumentsCleanupJob' => { 'cron' => '0 2 * * *', 'class' => 'DocumentsCleanupJob' } }
```

### 6. Encryption (Optional)

```ruby
# For sensitive metadata
class Document < ApplicationRecord
  attr_encrypted :metadata, key: ENV['DOCUMENT_ENCRYPTION_KEY']
end

# Generate key
require 'securerandom'
ENV['DOCUMENT_ENCRYPTION_KEY'] = SecureRandom.random_bytes(32).unpack('H*').first
```

## Frontend Authorization

### React Component Authorization

```typescript
// web/components/documents/DocumentGenerator.tsx
import { useAuth } from '@/lib/hooks/useAuth';

export function DocumentGenerator({
  onDocumentGenerated,
  showStats
}: DocumentGeneratorProps) {
  const { user } = useAuth();
  
  const canGenerate = user?.roles?.includes('finance') || 
                     user?.roles?.includes('admin');
  
  const canBatchGenerate = user?.roles?.includes('finance_head') ||
                          user?.roles?.includes('admin');

  const canArchive = user?.roles?.includes('admin');

  if (!canGenerate) {
    return (
      <div className="p-4 bg-yellow-50 border border-yellow-200 rounded">
        <p className="text-yellow-800">
          You don't have permission to generate documents.
          Contact your administrator.
        </p>
      </div>
    );
  }

  return (
    <div>
      {/* Normal component content */}
      {canBatchGenerate && (
        <button onClick={handleBatchGenerate}>
          Batch Generate
        </button>
      )}
      
      {canArchive && (
        <button onClick={handleArchive}>
          Archive
        </button>
      )}
    </div>
  );
}
```

## Testing Authorization

```ruby
# spec/policies/document_policy_spec.rb
describe DocumentPolicy do
  let(:user) { create(:user, roles: ['finance']) }
  let(:admin_user) { create(:user, roles: ['admin']) }
  let(:organization) { create(:organization) }
  let(:document) do
    create(:document, organization_id: organization.id)
  end

  describe '#generate?' do
    it 'allows finance users' do
      policy = DocumentPolicy.new(user, document)
      expect(policy.generate?).to be_truthy
    end

    it 'allows admins' do
      policy = DocumentPolicy.new(admin_user, document)
      expect(policy.generate?).to be_truthy
    end

    it 'denies view_only users' do
      view_only_user = create(:user, roles: ['view_only'])
      policy = DocumentPolicy.new(view_only_user, document)
      expect(policy.generate?).to be_falsy
    end
  end

  describe '#archive?' do
    it 'allows admins' do
      policy = DocumentPolicy.new(admin_user, document)
      expect(policy.archive?).to be_truthy
    end

    it 'denies finance users' do
      policy = DocumentPolicy.new(user, document)
      expect(policy.archive?).to be_falsy
    end
  end
end
```

## Deployment Checklist

- [ ] DOCUMENT_ENCRYPTION_KEY set in production environment
- [ ] Pundit policy files reviewed for security
- [ ] Rate limiting configured in production
- [ ] Audit logging enabled
- [ ] GDPR cleanup jobs scheduled
- [ ] SSL/TLS configured for document downloads
- [ ] File permissions locked down (no world-readable)
- [ ] Backup strategy for archived documents

---

**Version**: 1.0  
**Last Updated**: March 23, 2026  
**Status**: 🔒 Authorization Framework Ready
