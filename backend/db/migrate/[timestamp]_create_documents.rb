# Migration: Create Documents table

class CreateDocuments < ActiveRecord::Migration[6.0]
  def change
    create_table :documents, id: :uuid, default: 'gen_random_uuid()' do |t|
      # Organization & relationships
      t.uuid :organization_id, null: false
      t.uuid :reference_id, null: true  # Link to Invoice, SalesOrder, DeliveryTrip, etc.

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
      t.uuid :generated_by_user_id, null: true  # User who initiated generation
      t.datetime :generated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :archived_at, null: true

      t.timestamps
      t.index [:organization_id, :document_type]
      t.index [:organization_id, :reference_id]
      t.index [:organization_id, :created_at]
      t.foreign_key :organizations, column: :organization_id
    end

    # Archive old documents (lifecycle management)
    add_index :documents, [:status, :created_at], name: 'idx_documents_status_created_at'
  end
end
