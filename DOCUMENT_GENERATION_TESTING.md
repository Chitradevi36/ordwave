# Document Generation - Complete Testing Guide

## Testing Strategy Overview

Comprehensive testing approach for the document generation system:

1. **Unit Tests** - Service, Model, and method-level tests
2. **Integration Tests** - API endpoints, database, and external services
3. **End-to-End Tests** - Full workflow through React components
4. **Performance Tests** - Generation speed and storage optimization

## Setup

### Add Test Dependencies

```ruby
# backend/Gemfile (in test group)
group :test do
  gem 'rspec-rails', '~> 6.0'
  gem 'factory_bot_rails', '~> 6.2'
  gem 'faker', '~> 3.0'
  gem 'vcr', '~> 6.1'  # For mocking HTTP requests
  gem 'webmock', '~> 3.18'
  gem 'pdf-inspector', '~> 1.3'  # For PDF analysis
end
```

```bash
bundle install
rails generate rspec:install
```

### Configuration

```ruby
# spec/rails_helper.rb
require 'spec_helper'
require 'rspec/rails'
require 'pdf/inspector'

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  config.use_transactional_fixtures = true
  config.filter_rails_from_backtrace!
  
  # Include FactoryBot syntax
  config.include FactoryBot::Syntax::Methods
  
  # Include helpers
  config.include AuthenticationHelpers
  config.include DocumentHelpers
end
```

## Unit Tests

### Service Layer Tests

```ruby
# spec/services/document_generator_service_spec.rb
describe DocumentGeneratorService do
  let(:service) { described_class.new }
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization_id: organization.id) }

  describe '#generate' do
    let(:invoice_data) do
      {
        invoice_id: 'INV-001',
        amount: 5000,
        subtotal: 5000,
        tax_amount: 900,
        tax_rate: 18,
        customer: {
          name: 'Acme Corp',
          address: '123 Main Street',
          city: 'Mumbai',
          state: 'Maharashtra',
          zip: '400001',
          phone: '+91-9876543210',
          gst_number: '27AABCT1234H1Z0'
        },
        organization: {
          name: 'OrdWave Inc.',
          address: '456 Business Park',
          phone: '+91-9865432100',
          email: 'billing@ordwave.com',
          gst_number: '27AABCT9999H1Z0'
        },
        items: [
          {
            description: 'Product A',
            quantity: 10,
            unit: 'units',
            unit_price: 500,
            amount: 5000
          }
        ]
      }
    end

    context 'with valid invoice data' do
      it 'generates PDF binary' do
        pdf = service.generate(:invoice, invoice_data, 'invoice-001.pdf')
        expect(pdf).to be_a(String)
        expect(pdf.start_with?('%PDF')).to be_truthy
      end

      it 'creates valid PDF' do
        pdf = service.generate(:invoice, invoice_data, 'invoice-001.pdf')
        reader = PDF::Inspector::Text.analyze(pdf)
        expect(reader.text).to include('INV-001')
        expect(reader.text).to include('Acme Corp')
      end

      it 'includes all invoice items' do
        pdf = service.generate(:invoice, invoice_data, 'invoice-001.pdf')
        reader = PDF::Inspector::Text.analyze(pdf)
        expect(reader.text).to include('Product A')
        expect(reader.text).to include('10')
      end

      it 'calculates totals correctly' do
        pdf = service.generate(:invoice, invoice_data, 'invoice-001.pdf')
        reader = PDF::Inspector::Text.analyze(pdf)
        expect(reader.text).to include('5900')  # Total amount
      end
    end

    context 'with missing required fields' do
      it 'raises error when invoice_id missing' do
        data = invoice_data.except(:invoice_id)
        expect {
          service.generate(:invoice, data, 'invoice.pdf')
        }.to raise_error(DocumentGeneratorService::InvalidDocumentTypeError)
      end

      it 'raises error when customer missing' do
        data = invoice_data.except(:customer)
        expect {
          service.generate(:invoice, data, 'invoice.pdf')
        }.to raise_error(DocumentGeneratorService::RenderingError)
      end
    end

    context 'with invalid document type' do
      it 'raises error for unknown type' do
        expect {
          service.generate(:unknown_type, invoice_data, 'doc.pdf')
        }.to raise_error(DocumentGeneratorService::InvalidDocumentTypeError)
      end
    end

    %w[invoice waybill ewaybill delivery_receipt credit_note].each do |doc_type|
      it "supports #{doc_type} document type" do
        data = build("#{doc_type}_data")
        pdf = service.generate(doc_type, data, "#{doc_type}.pdf")
        expect(pdf.start_with?('%PDF')).to be_truthy
      end
    end
  end

  describe '#generate_and_save' do
    let(:invoice_data) { build(:invoice_data) }

    it 'creates document record in database' do
      expect {
        service.generate_and_save(
          :invoice,
          invoice_data,
          organization.id,
          metadata: { source: 'api' }
        )
      }.to change(Document, :count).by(1)
    end

    it 'stores PDF binary content' do
      document = service.generate_and_save(
        :invoice,
        invoice_data,
        organization.id,
        metadata: { source: 'api' }
      )
      expect(document.content).to start_with('%PDF')
    end

    it 'calculates file hash' do
      document = service.generate_and_save(
        :invoice,
        invoice_data,
        organization.id,
        metadata: { source: 'api' }
      )
      expect(document.file_hash).to match(/^[a-f0-9]{64}$/)  # SHA256
    end

    it 'stores metadata' do
      document = service.generate_and_save(
        :invoice,
        invoice_data,
        organization.id,
        metadata: { source: 'api', invoice_id: 'INV-001' }
      )
      expect(document.metadata['source']).to eq('api')
      expect(document.metadata['invoice_id']).to eq('INV-001')
    end

    it 'generates unique filename' do
      doc1 = service.generate_and_save(:invoice, invoice_data, organization.id)
      doc2 = service.generate_and_save(:invoice, invoice_data, organization.id)
      expect(doc1.filename).not_to eq(doc2.filename)
    end
  end

  describe '#batch_generate' do
    let(:invoices_data) do
      3.times.map { build(:invoice_data) }
    end

    it 'generates multiple documents' do
      expect {
        service.batch_generate(:invoice, invoices_data, organization.id)
      }.to change(Document, :count).by(3)
    end

    it 'returns array of documents' do
      documents = service.batch_generate(:invoice, invoices_data, organization.id)
      expect(documents).to be_an(Array)
      expect(documents.length).to eq(3)
      expect(documents.all? { |d| d.is_a?(Document) }).to be_truthy
    end

    it 'handles partial failures gracefully' do
      mixed_data = [
        build(:invoice_data),
        build(:invoice_data, invoice_id: nil),  # Invalid
        build(:invoice_data)
      ]
      
      expect {
        service.batch_generate(:invoice, mixed_data, organization.id)
      }.not_to raise_error
      
      documents = service.batch_generate(:invoice, mixed_data, organization.id)
      expect(documents.length).to be >= 2
    end
  end

  describe '#regenerate' do
    let(:document) { create(:document, organization_id: organization.id) }
    let(:updated_data) { build(:invoice_data) }

    it 'updates document content' do
      original_content = document.content
      
      service.regenerate(document.id, updated_data)
      document.reload
      
      expect(document.content).not_to eq(original_content)
    end

    it 'updates file hash' do
      original_hash = document.file_hash
      
      service.regenerate(document.id, updated_data)
      document.reload
      
      expect(document.file_hash).not_to eq(original_hash)
    end

    it 'updates status to regenerated' do
      service.regenerate(document.id, updated_data)
      document.reload
      
      expect(document.status).to eq('regenerated')
    end

    it 'preserves organization_id' do
      service.regenerate(document.id, updated_data)
      document.reload
      
      expect(document.organization_id).to eq(organization.id)
    end
  end
end
```

### Model Tests

```ruby
# spec/models/document_spec.rb
describe Document do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization_id: organization.id) }
  let(:document) do
    create(:document, 
      organization_id: organization.id,
      generated_by_user_id: user.id
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:generated_by_user).optional }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:document_type) }
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_presence_of(:content) }
    
    it do
      is_expected.to validate_inclusion_of(:document_type)
        .in_array(%w[invoice waybill ewaybill delivery_receipt credit_note])
    end

    it 'validates uniqueness of filename per organization' do
      doc = build(:document, 
        organization_id: organization.id,
        filename: document.filename
      )
      expect(doc).to be_invalid
      expect(doc.errors[:filename]).to include('has already been taken')
    end

    it 'validates content size limit' do
      doc = build(:document,
        content: 'x' * (51.megabytes)
      )
      expect(doc).to be_invalid
      expect(doc.errors[:size_bytes]).to be_present
    end
  end

  describe 'scopes' do
    before do
      create(:document, organization_id: organization.id, document_type: 'invoice')
      create(:document, organization_id: organization.id, document_type: 'waybill')
      create(:document, 
        organization_id: create(:organization).id, 
        document_type: 'invoice'
      )
    end

    describe '.for_org' do
      it 'returns only documents for organization' do
        docs = Document.for_org(organization.id)
        expect(docs.length).to eq(2)
        expect(docs.all? { |d| d.organization_id == organization.id }).to be_truthy
      end
    end

    describe '.by_type' do
      it 'returns documents of specific type' do
        docs = Document.by_type('invoice')
        expect(docs.all? { |d| d.document_type == 'invoice' }).to be_truthy
      end
    end

    describe '.active' do
      it 'excludes archived documents' do
        create(:document, 
          organization_id: organization.id,
          archived_at: Time.current
        )
        docs = Document.active
        expect(docs.all? { |d| d.archived_at.nil? }).to be_truthy
      end
    end

    describe '.recent' do
      it 'orders by created_at descending' do
        docs = Document.recent.limit(2)
        expect(docs[0].created_at).to be >= docs[1].created_at
      end
    end

    describe '.by_date_range' do
      it 'returns documents within date range' do
        old_doc = create(:document, 
          organization_id: organization.id,
          created_at: 30.days.ago
        )
        new_doc = create(:document,
          organization_id: organization.id,
          created_at: Time.current
        )
        
        docs = Document.by_date_range(10.days.ago, Time.current)
        expect(docs).to include(new_doc)
        expect(docs).not_to include(old_doc)
      end
    end
  end

  describe 'callbacks' do
    describe '#calculate_file_hash' do
      it 'generates SHA256 hash on create' do
        doc = create(:document)
        expect(doc.file_hash).to match(/^[a-f0-9]{64}$/)
      end

      it 'updates hash when content changes' do
        original_hash = document.file_hash
        document.content = 'new content'
        document.save!
        expect(document.file_hash).not_to eq(original_hash)
      end
    end
  end

  describe '#archive!' do
    it 'sets archived_at timestamp' do
      expect(document.archived_at).to be_nil
      document.archive!
      expect(document.archived_at).not_to be_nil
    end

    it 'changes status' do
      document.archive!
      expect(document.status).to eq('archived')
    end

    it 'prevents deletion' do
      document.archive!
      expect { document.destroy }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe '#regeneratable?' do
    it 'returns true for non-archived docs' do
      expect(document.regeneratable?).to be_truthy
    end

    it 'returns false for archived docs' do
      document.archive!
      expect(document.regeneratable?).to be_falsy
    end
  end

  describe '#download_data' do
    it 'returns content and filename for download' do
      data = document.download_data
      expect(data[:content]).to eq(document.content)
      expect(data[:filename]).to eq(document.filename)
      expect(data[:mime_type]).to eq('application/pdf')
    end
  end

  describe '#size_formatted' do
    it 'formats bytes to human readable' do
      document.update!(size_bytes: 1024)
      expect(document.size_formatted).to eq('1.00 KB')
    end

    it 'handles megabytes' do
      document.update!(size_bytes: 1024 * 1024)
      expect(document.size_formatted).to eq('1.00 MB')
    end
  end

  describe '.statistics_for_org' do
    before do
      create(:document, organization_id: organization.id, document_type: 'invoice')
      create(:document, organization_id: organization.id, document_type: 'waybill')
      create(:document, organization_id: organization.id, document_type: 'invoice')
      create(:document, organization_id: create(:organization).id)
    end

    it 'returns statistics for organization' do
      stats = Document.statistics_for_org(organization.id)
      
      expect(stats[:total_count]).to eq(3)
      expect(stats[:by_type]['invoice']).to eq(2)
      expect(stats[:by_type]['waybill']).to eq(1)
    end

    it 'includes size statistics' do
      stats = Document.statistics_for_org(organization.id)
      expect(stats[:total_size_mb]).to be_a(Float)
      expect(stats[:average_size_kb]).to be_a(Float)
    end
  end
end
```

## Integration Tests

### API Controller Tests

```ruby
# spec/requests/api/v1/documents_spec.rb
describe 'Documents API' do
  let(:organization) { create(:organization) }
  let(:user) { create(:user, organization_id: organization.id, roles: ['finance']) }
  let(:headers) { { Authorization: "Bearer #{create_jwt_token(user)}" } }

  describe 'POST /api/v1/documents/generate' do
    let(:invoice_data) do
      {
        document: {
          type: 'invoice',
          data: build(:invoice_data).stringify_keys
        }
      }
    end

    context 'with valid parameters' do
      it 'returns 201 created' do
        post '/api/v1/documents/generate', 
          params: invoice_data,
          headers: headers
        
        expect(response).to have_http_status(:created)
      end

      it 'returns document details' do
        post '/api/v1/documents/generate',
          params: invoice_data,
          headers: headers
        
        json = JSON.parse(response.body)
        expect(json.dig('data', 'id')).to be_present
        expect(json.dig('data', 'filename')).to end_with('.pdf')
        expect(json.dig('data', 'download_url')).to be_present
      end

      it 'creates document in database' do
        expect {
          post '/api/v1/documents/generate',
            params: invoice_data,
            headers: headers
        }.to change(Document, :count).by(1)
      end
    end

    context 'with permission denied' do
      let(:view_only_user) do
        create(:user, organization_id: organization.id, roles: ['view_only'])
      end
      let(:unauthorized_headers) do
        { Authorization: "Bearer #{create_jwt_token(view_only_user)}" }
      end

      it 'returns 403 forbidden' do
        post '/api/v1/documents/generate',
          params: invoice_data,
          headers: unauthorized_headers
        
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with invalid document type' do
      it 'returns 422 unprocessable entity' do
        post '/api/v1/documents/generate',
          params: { document: { type: 'invalid', data: {} } },
          headers: headers
        
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/documents' do
    before do
      create(:document, organization_id: organization.id, document_type: 'invoice')
      create(:document, organization_id: organization.id, document_type: 'waybill')
      create(:document, organization_id: create(:organization).id)
    end

    it 'returns documents for organization' do
      get '/api/v1/documents', headers: headers
      
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(2)
    end

    it 'filters by type' do
      get '/api/v1/documents?type=invoice', headers: headers
      
      json = JSON.parse(response.body)
      expect(json['data'].all? { |d| d['type'] == 'invoice' }).to be_truthy
    end

    it 'supports pagination' do
      get '/api/v1/documents?per_page=1', headers: headers
      
      json = JSON.parse(response.body)
      expect(json['data'].length).to eq(1)
      expect(json.dig('meta', 'total')).to eq(2)
    end
  end

  describe 'GET /api/v1/documents/:id/download' do
    let(:document) { create(:document, organization_id: organization.id) }

    it 'returns PDF file' do
      get "/api/v1/documents/#{document.id}/download", headers: headers
      
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
    end

    it 'includes attachment header' do
      get "/api/v1/documents/#{document.id}/download", headers: headers
      
      expect(response.headers['Content-Disposition'])
        .to include('attachment')
        .and include(document.filename)
    end
  end

  describe 'PATCH /api/v1/documents/:id/regenerate' do
    let(:document) { create(:document, organization_id: organization.id) }
    let(:updated_data) { build(:invoice_data).stringify_keys }

    it 'regenerates document' do
      original_content = document.content
      
      patch "/api/v1/documents/#{document.id}/regenerate",
        params: { document: { data: updated_data } },
        headers: headers
      
      document.reload
      expect(document.content).not_to eq(original_content)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'DELETE /api/v1/documents/:id/archive' do
    let(:admin_user) do
      create(:user, organization_id: organization.id, roles: ['admin'])
    end
    let(:admin_headers) do
      { Authorization: "Bearer #{create_jwt_token(admin_user)}" }
    end
    let(:document) { create(:document, organization_id: organization.id) }

    it 'archives document' do
      delete "/api/v1/documents/#{document.id}/archive",
        headers: admin_headers
      
      document.reload
      expect(document.archived_at).not_to be_nil
      expect(response).to have_http_status(:ok)
    end

    it 'forbids non-admin users' do
      delete "/api/v1/documents/#{document.id}/archive",
        headers: headers
      
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /api/v1/documents/statistics' do
    let(:admin_user) do
      create(:user, organization_id: organization.id, roles: ['admin'])
    end
    let(:admin_headers) do
      { Authorization: "Bearer #{create_jwt_token(admin_user)}" }
    end

    before do
      create(:document, organization_id: organization.id, document_type: 'invoice')
      create(:document, organization_id: organization.id, document_type: 'waybill')
    end

    it 'returns statistics' do
      get '/api/v1/documents/statistics', headers: admin_headers
      
      json = JSON.parse(response.body)
      expect(json.dig('data', 'total_count')).to eq(2)
      expect(json.dig('data', 'by_type')).to be_present
    end

    it 'forbids non-admin users' do
      get '/api/v1/documents/statistics', headers: headers
      
      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

## End-to-End Tests

### React Component Tests

```typescript
// web/components/documents/__tests__/DocumentGenerator.test.ts
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DocumentGenerator } from '../DocumentGenerator';

describe('DocumentGenerator Component', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders component with title', () => {
    render(<DocumentGenerator />);
    expect(screen.getByText('Document Generator')).toBeInTheDocument();
  });

  it('displays statistics cards', async () => {
    render(<DocumentGenerator showStats={true} />);
    
    await waitFor(() => {
      expect(screen.getByText('Total Documents')).toBeInTheDocument();
      expect(screen.getByText('This Month')).toBeInTheDocument();
    });
  });

  it('allows document type selection', async () => {
    render(<DocumentGenerator />);
    
    const typeSelect = screen.getByLabelText('Document Type');
    await userEvent.selectOption(typeSelect, 'invoice');
    
    expect(typeSelect).toHaveValue('invoice');
  });

  it('generates document on button click', async () => {
    const mockOnGenerate = jest.fn();
    render(
      <DocumentGenerator onDocumentGenerated={mockOnGenerate} />
    );
    
    const generateButton = screen.getByRole('button', { name: /generate/i });
    await userEvent.click(generateButton);
    
    await waitFor(() => {
      expect(mockOnGenerate).toHaveBeenCalledWith(expect.any(Object));
    });
  });

  it('displays error message on generation failure', async () => {
    // Mock API to return error
    jest.spyOn(global, 'fetch').mockRejectedValueOnce(
      new Error('Generation failed')
    );
    
    render(<DocumentGenerator />);
    
    const generateButton = screen.getByRole('button', { name: /generate/i });
    await userEvent.click(generateButton);
    
    await waitFor(() => {
      expect(screen.getByText(/generation failed/i)).toBeInTheDocument();
    });
  });

  it('lists generated documents', async () => {
    render(<DocumentGenerator />);
    
    await waitFor(() => {
      expect(screen.getByText('Recent Documents')).toBeInTheDocument();
    });
    
    const documentList = screen.getByRole('list');
    expect(documentList.children.length).toBeGreaterThan(0);
  });

  it('downloads document on click', async () => {
    const mockDownload = jest.fn();
    global.fetch = jest.fn(() =>
      Promise.resolve({
        blob: () => Promise.resolve(new Blob()),
        ok: true
      })
    );
    
    render(<DocumentGenerator />);
    
    const downloadButtons = screen.getAllByRole('button', { name: /download/i });
    await userEvent.click(downloadButtons[0]);
    
    await waitFor(() => {
      expect(global.fetch).toHaveBeenCalled();
    });
  });
});
```

## Performance Tests

```ruby
# spec/performance/document_generation_spec.rb
describe 'Document Generation Performance' do
  let(:organization) { create(:organization) }
  let(:service) { DocumentGeneratorService.new }

  describe 'generation speed' do
    it 'generates invoice in < 500ms' do
      data = build(:invoice_data)
      
      start_time = Time.now
      service.generate(:invoice, data, 'bench-invoice.pdf')
      elapsed = (Time.now - start_time) * 1000
      
      expect(elapsed).to be < 500
    end

    it 'batch generates 100 invoices in < 30s' do
      documents_data = 100.times.map { build(:invoice_data) }
      
      start_time = Time.now
      service.batch_generate(:invoice, documents_data, organization.id)
      elapsed = Time.now - start_time
      
      expect(elapsed).to be < 30
    end
  end

  describe 'storage optimization' do
    it 'stores duplicate content efficiently' do
      data = build(:invoice_data)
      pdf = service.generate(:invoice, data, 'test.pdf')
      
      doc1 = create(:document, content: pdf, organization_id: organization.id)
      
      # Simulate duplicate with same hash
      duplicate_pdf = pdf  # Same content
      expect(Digest::SHA256.hexdigest(duplicate_pdf))
        .to eq(doc1.file_hash)
    end
  end

  describe 'memory usage' do
    it 'handles large batch without memory issues' do
      documents_data = 500.times.map { build(:invoice_data) }
      
      expect {
        service.batch_generate(:invoice, documents_data, organization.id)
      }.not_to raise_error
    end
  end
end
```

## Running Tests

```bash
# All tests
bundle exec rspec spec/

# Unit tests only
bundle exec rspec spec/services/ spec/models/

# API integration tests only
bundle exec rspec spec/requests/

# With coverage
bundle exec rspec --format progress --format RcovCoverageFormatter

# Run test file
bundle exec rspec spec/services/document_generator_service_spec.rb

# Run specific test
bundle exec rspec spec/services/document_generator_service_spec.rb:42
```

## Coverage Goals

- **Target**: 85%+ overall coverage
- **Service Layer**: 95%+ (critical path)
- **Model Layer**: 90%+
- **API Layer**: 85%+
- **Templates**: 75%+ (visual inspection sufficient)

---

**Version**: 1.0  
**Last Updated**: March 23, 2026  
**Status**: 📋 Test Suite Ready for Implementation
