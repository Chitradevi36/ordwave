# Event-Triggered Accounting Sync Automation

## Overview
Enhance the accounting sync module from manual batch exports to an automatic, event-driven system that syncs order and payment data to Tally based on business triggers and schedules.

---

## Problem Statement
- Currently: Users must manually create XML exports or rely on fixed schedules
- Missing: Automatic sync on critical business events (order approved, delivered, payment received)
- Limitation: No scalability for multiple integrations
- Gap: Each integration requires separate configuration instead of org-wide workflow settings

---

## Proposed Solution

### Phase 1: Add Workflow Configuration Fields

Add these to `WorkflowSettings` in organization workflow settings:

```typescript
interface WorkflowSettings {
  // Existing fields...
  order_approval_mode: "automatic" | "manager_approval" | "above_threshold";
  order_approval_threshold: string;
  // ... other order/dispatch/credit fields ...
  
  // NEW: Accounting sync automation
  sync_auto_on_order_approved: boolean;
  sync_auto_on_order_delivered: boolean;
  sync_auto_on_payment_received: boolean;
  sync_auto_on_collection: boolean;
  sync_schedule_cron: string;           // "disabled" | "daily_6pm" | "twice_daily" | "every_4_hours"
  sync_batch_size: string;              // Default: "100"
  sync_include_stock_movements: boolean;
}
```

**Default Values:**
```ruby
const WF_DEFAULTS: WorkflowSettings = {
  // ... existing ...
  sync_auto_on_order_approved: false,
  sync_auto_on_order_delivered: false,
  sync_auto_on_payment_received: false,
  sync_auto_on_collection: false,
  sync_schedule_cron: 'disabled',
  sync_batch_size: '100',
  sync_include_stock_movements: false,
};
```

---

### Phase 2: Backend Event Hooks

#### Hook 1: Order Approved

**File:** `backend/app/services/orders/approve_order_service.rb`

After order is approved, trigger sync:

```ruby
def call
  # ... existing approval logic ...
  
  ActiveRecord::Base.transaction do
    # ... existing code ...
    
    # Trigger accounting sync if enabled
    after_approve_trigger_sync(result[:order]) if result[:ok]
  end
  
  result
end

private

def after_approve_trigger_sync(order)
  settings = order.organization.settings || {}
  return unless settings['sync_auto_on_order_approved'] == true
  
  Accounting::Sync::CreateSyncRecordService.call(
    organization: order.organization,
    trigger_type: 'order_approved',
    source_type: 'SalesOrder',
    source_id: order.id,
    data_types: ['invoices']
  )
rescue StandardError => e
  Rails.logger.warn("[ApproveOrderService] Sync trigger failed: #{e.message}")
end
```

#### Hook 2: Order Delivered

**File:** `backend/app/services/delivery/complete_stop_service.rb`

After delivery stop is completed:

```ruby
def call
  # ... existing completion logic ...
  
  ActiveRecord::Base.transaction do
    # ... existing code ...
    
    # Trigger accounting sync if enabled
    after_delivery_trigger_sync(order) if completed_successfully?
  end
  
  result
end

private

def after_delivery_trigger_sync(order)
  settings = order.organization.settings || {}
  return unless settings['sync_auto_on_order_delivered'] == true
  
  data_types = ['invoices']
  data_types << 'stock_movements' if settings['sync_include_stock_movements'] == true
  
  Accounting::Sync::CreateSyncRecordService.call(
    organization: order.organization,
    trigger_type: 'order_delivered',
    source_type: 'SalesOrder',
    source_id: order.id,
    data_types: data_types
  )
rescue StandardError => e
  Rails.logger.warn("[CompleteStopService] Sync trigger failed: #{e.message}")
end
```

#### Hook 3: Payment Confirmed

**File:** `backend/app/services/payments/confirm_payment_service.rb`

After payment is confirmed:

```ruby
def call
  # ... existing confirmation logic ...
  
  if confirmed?
    # ... existing code ...
    
    # Trigger accounting sync if enabled
    after_payment_trigger_sync(payment) if result[:ok]
  end
  
  result
end

private

def after_payment_trigger_sync(payment)
  settings = payment.organization.settings || {}
  return unless settings['sync_auto_on_payment_received'] == true
  
  Accounting::Sync::CreateSyncRecordService.call(
    organization: payment.organization,
    trigger_type: 'payment_confirmed',
    source_type: 'Payment',
    source_id: payment.id,
    data_types: ['payments', 'payment_allocations']
  )
rescue StandardError => e
  Rails.logger.warn("[ConfirmPaymentService] Sync trigger failed: #{e.message}")
end
```

---

### Phase 3: Create Sync Record Model

**File (new):** `backend/app/models/accounting_sync_record.rb`

```ruby
class AccountingSyncRecord < ApplicationRecord
  belongs_to :organization
  belongs_to :accounting_integration, optional: true
  belongs_to :source, polymorphic: true, optional: true
  
  enum status: { 
    pending: 'pending', 
    processing: 'processing', 
    synced: 'synced', 
    failed: 'failed',
    skipped: 'skipped'
  }
  
  enum trigger_type: { 
    manual: 'manual',
    order_approved: 'order_approved',
    order_delivered: 'order_delivered',
    payment_confirmed: 'payment_confirmed',
    collection: 'collection',
    scheduled: 'scheduled'
  }
  
  store_accessor :data_types, prefix: true
  
  validates :organization_id, :trigger_type, :status, presence: true
  
  scope :pending, -> { where(status: 'pending') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, -> { where('created_at > ?', 1.hour.ago) }
  scope :by_trigger, ->(trigger) { where(trigger_type: trigger) }
  
  # Return associated integration or fall back to primary for org
  def integration
    @integration ||= accounting_integration || 
                     AccountingIntegration.where(
                       organization_id: organization_id,
                       status: 'connected'
                     ).first
  end
  
  def mark_synced!(export_file_id = nil)
    update!(
      status: 'synced',
      export_file_id: export_file_id,
      synced_at: Time.current
    )
  end
  
  def mark_failed!(error_message)
    update!(
      status: 'failed',
      error_message: error_message,
      failed_at: Time.current
    )
  end
  
  def retry_if_failed
    return unless failed?
    return if retry_count.to_i >= 3
    
    update!(
      status: 'pending',
      retry_count: (retry_count.to_i) + 1
    )
  end
end
```

**Migration:**

```ruby
class CreateAccountingSyncRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :accounting_sync_records do |t|
      t.bigint :organization_id, null: false
      t.bigint :accounting_integration_id
      t.references :source, polymorphic: true, optional: true
      
      t.string :status, default: 'pending'
      t.string :trigger_type, null: false
      t.json :data_types, default: []
      
      t.text :error_message
      t.integer :retry_count, default: 0
      t.bigint :export_file_id
      
      t.datetime :synced_at
      t.datetime :failed_at
      
      t.timestamps
      t.index [:organization_id, :status]
      t.index [:trigger_type, :status]
      t.index [:accounting_integration_id, :status]
      t.foreign_key :organizations
      t.foreign_key :accounting_integrations, optional: true
    end
  end
end
```

---

### Phase 4: Create Sync Record Service

**File (new):** `backend/app/services/accounting/sync/create_sync_record_service.rb`

```ruby
module Accounting
  module Sync
    class CreateSyncRecordService
      def self.call(**kwargs)
        new(**kwargs).call
      end
      
      def initialize(organization:, trigger_type:, data_types:, source_type: nil, source_id: nil, accounting_integration: nil)
        @organization = organization
        @trigger_type = trigger_type
        @data_types = data_types
        @source_type = source_type
        @source_id = source_id
        @accounting_integration = accounting_integration
      end
      
      def call
        # Find active integration if not provided
        integration = @accounting_integration || 
                      AccountingIntegration.where(
                        organization_id: @organization.id,
                        status: 'connected'
                      ).first
        
        return Result.new(
          success: false,
          error: 'No active accounting integration found'
        ) unless integration
        
        # Avoid duplicate syncs within 5 minutes for same source
        if recent_duplicate_exists?
          return Result.new(
            success: false,
            error: 'Duplicate sync already pending',
            duplicate: true
          )
        end
        
        # Create sync record
        record = AccountingSyncRecord.create!(
          organization: @organization,
          accounting_integration: integration,
          source_type: @source_type,
          source_id: @source_id,
          trigger_type: @trigger_type,
          status: 'pending',
          data_types: @data_types
        )
        
        Result.new(success: true, record: record)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(success: false, error: e.message)
      end
      
      private
      
      def recent_duplicate_exists?
        return false unless @source_type && @source_id
        
        AccountingSyncRecord
          .where(
            source_type: @source_type,
            source_id: @source_id,
            trigger_type: @trigger_type,
            status: 'pending'
          )
          .where('created_at > ?', 5.minutes.ago)
          .exists?
      end
    end
    
    class Result < Struct.new(:success, :record, :error, :duplicate, keyword_init: true)
      def success?
        success == true
      end
    end
  end
end
```

---

### Phase 5: Scheduled Batch Job

**File (new):** `backend/app/jobs/accounting/auto_sync_triggered_records_job.rb`

```ruby
module Accounting
  class AutoSyncTriggeredRecordsJob < ApplicationJob
    queue_as :accounting
    sidekiq_options retry: 3
    
    def perform
      # Find pendingrecords from last hour
      pending_records = AccountingSyncRecord
        .pending
        .recent
        .group_by(&:organization_id)
      
      pending_records.each do |org_id, records|
        batch_sync_for_org(org_id, records)
      end
      
      # Retry failed syncs (up to 3 times)
      AccountingSyncRecord
        .failed
        .where('retry_count < 3')
        .where('failed_at > ?', 24.hours.ago)
        .find_each { |r| r.retry_if_failed }
    end
    
    private
    
    def batch_sync_for_org(org_id, records)
      org = Organization.find_by(id: org_id)
      return unless org
      
      integration = records.first.integration
      return unless integration&.active_for_sync?
      
      # Determine data types to sync (union of all pending records)
      data_types = records.flat_map(&:data_types).uniq
      
      # Create single batch export file
      export_file = AccountingExportFile.create!(
        organization: org,
        accounting_integration: integration,
        export_type: 'auto_sync',
        export_data_types: data_types,
        generated_by: system_user,
        status: 'generating',
        source_sync_records: records
      )
      
      # Mark records as processing
      records.each { |r| r.update(status: 'processing') }
      
      # Enqueue export generation job
      GenerateBatchExportJob.perform_later(export_file.id)
      
      Rails.logger.info(
        "[AutoSyncTriggeredRecordsJob] Enqueued export for org#{org_id} "\
        "with #{records.count} records, data_types: #{data_types.join(', ')}"
      )
    rescue StandardError => e
      Rails.logger.error("[AutoSyncTriggeredRecordsJob] Failed for org#{org_id}: #{e.message}")
      records.each { |r| r.mark_failed!(e.message) }
    end
    
    def system_user
      @system_user ||= User.system_user || User.first
    end
  end
end
```

**Add to `sidekiq.yml`:**

```yaml
scheduled_jobs:
  # ... existing jobs ...
  accounting_auto_sync:
    cron: '*/15 * * * *'        # Every 15 minutes
    class: 'Accounting::AutoSyncTriggeredRecordsJob'
    queue: accounting
    description: 'Process event-triggered accounting sync records and create batch exports'
```

---

### Phase 6: Update UI - Workflow Settings

**File:** `web/app/settings/organization/page.tsx`

Add new section after existing workflow cards:

```tsx
<SectionCard
  icon={<FileText className="h-4 w-4 text-accent" />}
  title="Accounting Auto-Sync"
  description="Automatically sync order and payment data to connected accounting software"
>
  <Toggle
    label="Sync after order approved"
    description="Automatically export invoice data when orders are approved"
    checked={wfForm.sync_auto_on_order_approved}
    onChange={(v) => setWf('sync_auto_on_order_approved', v)}
  />
  
  <Toggle
    label="Sync after order delivered"
    description="Automatically export invoice data when orders are delivered"
    checked={wfForm.sync_auto_on_order_delivered}
    onChange={(v) => setWf('sync_auto_on_order_delivered', v)}
  />
  
  {wfForm.sync_auto_on_order_delivered && (
    <Toggle
      label="Include stock movements"
      description="Also sync inventory adjustments when orders are delivered"
      checked={wfForm.sync_include_stock_movements}
      onChange={(v) => setWf('sync_include_stock_movements', v)}
    />
  )}
  
  <Toggle
    label="Sync after payment received"
    description="Automatically export payment data when payments are confirmed"
    checked={wfForm.sync_auto_on_payment_received}
    onChange={(v) => setWf('sync_auto_on_payment_received', v)}
  />
  
  <SelectField
    label="Scheduled sync frequency"
    value={wfForm.sync_schedule_cron}
    options={[
      { value: 'disabled', label: 'Disabled (event-triggered only)' },
      { value: 'daily_6pm', label: 'Daily at 6 PM' },
      { value: 'twice_daily', label: 'Twice daily (6 AM & 6 PM)' },
      { value: 'every_4_hours', label: 'Every 4 hours' },
      { value: 'every_hourly', label: 'Every hour' },
    ]}
    onChange={(v) => setWf('sync_schedule_cron', v)}
  />
  
  <Input
    label="Batch size (records per sync)"
    type="number"
    min="10"
    max="1000"
    value={wfForm.sync_batch_size}
    helperText="Number of records to include in each automatic sync batch"
    onChange={(e) => setWf('sync_batch_size', e.target.value)}
  />
</SectionCard>
```

---

### Phase 7: Update Sync Dashboard

Enhance accounting sync records dashboard to show:
- **Trigger type** (order approved, payment received, scheduled, manual)
- **Status** (pending, processing, synced, failed)
- **Source** (which order/payment triggered it)
- **Retry count** (for failed syncs)
- **Last synced** timestamp

**New columns in sync records table:**
```
| Trigger      | Source                  | Status   | Data Types           | Synced   | Retry |
|--------------|-------------------------|----------|----------------------|----------|-------|
| Order #1234  | Order Approved         | Synced   | invoices             | 2 mins   | -     |
| Payment #567 | Payment Confirmed      | Pending  | payments             | -        | 0/3   |
| Manual       | Export Center          | Synced   | all                  | 1 hr     | -     |
```

---

## Implementation Roadmap

### Week 1: Foundation
- [ ] Add workflow config fields
- [ ] Create AccountingSyncRecord model
- [ ] Create CreateSyncRecordService
- [ ] Add hooks to ApproveOrderService

### Week 2: Job & Automation
- [ ] Create AutoSyncTriggeredRecordsJob  
- [ ] Add hooks to CompleteStopService and PaymentService
- [ ] Update GenerateBatchExportService to handle sync records
- [ ] Add sidekiq schedule

### Week 3: UI & Testing
- [ ] Update workflow settings UI
- [ ] Update sync dashboard to show new fields
- [ ] Add audit logging for sync triggers
- [ ] Write tests for event hooks
- [ ] E2E testing

### Week 4: Monitoring & Docs
- [ ] Add alerting for failed syncs
- [ ] Create admin dashboard for sync health
- [ ] Write documentation
- [ ] Rollout

---

## Benefits

✅ **Zero manual intervention** - Syncs happen automatically based on business events  
✅ **Scalable** - Works with any accounting integration (Tally, Zoho, Busy, etc.)  
✅ **Configurable** - Organization can enable/disable specific triggers  
✅ **Resilient** - Failed syncs retry automatically (up to 3 times)  
✅ **Auditable** - Every sync is tracked with trigger type and source  
✅ **Non-disruptive** - Event hooks are try-catch wrapped; won't break order flow  
✅ **Real-time** - Orders/payments sync within minutes of approval  
✅ **Scheduled fallback** - If events fail, scheduled job catches it every 15 minutes  

---

## Future Enhancements

1. **Webhook outbound** - Send real-time webhooks to Tally API instead of just batch exports
2. **Conditional syncs** - Sync only if total > ₹X or quantity > Y
3. **Selective data** - User can choose which fields to sync per integration
4. **Mapping rules** - Auto-assign ledger accounts based on product categories
5. **Sync history** - Full audit trail with before/after comparison
6. **Smart deduplication** - Detect if same order already synced in Tally, skip it
7. **Two-way sync** - Pull master data updates from Tally back into OrdWave

---

## Questions for Refinement

1. Should scheduled sync also be a cron field (already captured in `sync_schedule_cron`)?
yes, we can use the `sync_schedule_cron` field to allow organizations to choose their preferred sync frequency. The options can include "disabled", "daily at 6 PM", "twice daily (6 AM & 6 PM)", "every 4 hours", and "every hour". This way, organizations can have both event-triggered syncs and scheduled batch syncs based on their needs.
2. Do we need per-integration settings, or org-wide only?
org-wide settings along with ability to disable sync for specific integrations if needed (e.g. if they have their own triggers) and based on workflow settings (e.g if sync_auto_on_order_approved is false, then even if integration is connected, it won't trigger on order approval)
3. Should failed syncs send notifications to managers?
yes, we can add an optional notification system that alerts managers of failed syncs after 3 retries, with details on the error and which orders/payments were affected. This can be implemented via email or in-app notifications.
4. Do we need manual retry button in UI, or only automatic retries?
We can have both. Automatic retries will happen up to 3 times with exponential backoff. Additionally, in the sync dashboard, we can add a "Retry Now" button for failed sync records that allows admins to manually trigger a retry immediately if they want to expedite the process after fixing any underlying issues.
5. Should sync wait for invoice generation, or trigger immediately on order approval?
For order approval, we can trigger immediately with the data available at that time (e.g. order details, customer info). The actual invoice generation can happen asynchronously, and the sync record can be updated with the invoice ID once it's generated. For delivery and payment triggers, we can include the relevant data at that time as well. This way, we ensure that critical events trigger syncs in real-time without waiting for invoice generation, while still allowing us to link the sync record to the generated invoice once it's ready.
