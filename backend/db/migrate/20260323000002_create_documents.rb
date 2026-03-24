# Migration: Create Documents table
# Generated: March 23, 2026

class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    # Enable uuid extension if not already enabled
    enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')

    create_table :documents, id: :uuid, default: 'uuid_generate_v4()' do |t|
      # Organization & relationships
      t.references :organization, null: false, foreign_key: true
      t.bigint :reference_id, null: true  # Link to Invoice, SalesOrder, DeliveryTrip, etc. (bigint for compatibility)

      # Document metadata
      t.string :document_type, null: false, index: true  # invoice, waybill, ewaybill, delivery_receipt, credit_note
      t.string :filename, null: false
      t.string :status, null: false, default: 'generated', index: true  # generated, regenerated, archived
      t.integer :size_bytes, null: false  # File size in bytes
      t.string :file_hash, null: true  # SHA256 hash for deduplication

      # Content storage (as binary, not ActiveStorage for performance)
      t.binary :content, null: false, limit: 50.megabytes

      # Metadata as JSONB
      t.jsonb :metadata, default: {}, null: false  # generated_at, template_version, custom_data, etc.

      # Audit trail
      t.references :generated_by_user, null: true, foreign_key: { to_table: :users }
      t.datetime :archived_at, null: true

      t.timestamps

      t.index [:organization_id, :document_type]
      t.index [:organization_id, :reference_id]
      t.index [:organization_id, :created_at]
      t.index [:status, :created_at], name: 'idx_documents_status_created_at'
    end
  end
end
