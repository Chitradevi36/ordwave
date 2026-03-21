# Feature 16: Bank Match Auto-Posting with AI Confidence Scoring
## Detailed Technical Design Document

**Status**: Design Phase  
**Owner**: Development Team  
**Priority**: Very High (Tier 1, 85-260 min/week savings)  
**Estimated Effort**: 60-80 hours  
**Timeline**: 2 weeks (sprint)  
**Test Coverage**: 70+ test cases  

---

## 1. Overview & Goals

### Business Problem
- **Current State**: 10-15 medium-confidence transaction matches per day (50-150 min/week)
- **Bottleneck**: Finance manually reviews and approves each match at 85%+ confidence
- **Opportunity**: Auto-post high-confidence matches (≥95%) with 1-hour rejection window

### Success Metrics
- **Primary**: 85%+ of daily matches auto-posted (eliminates 85-120 min/week)
- **Secondary**: <2% false positive rate, 99% accuracy on auto-posted transactions
- **Operational**: <1 minute average time to reject an auto-posted transaction
- **Learning**: Confidence thresholds improve month-over-month (ML feedback loop)

### Key Constraints
- Must maintain 1-hour rejection window for Finance intervention
- Auto-posting requires immediate audit trail + notification
- Payment reversal must be instant + idempotent
- Compliance: All auto-posts fully logged for regulatory review

---

## 2. Architecture & System Design

### 2.1 Component Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     BANK FEED PROCESSOR                               │
│  (Existing - enhanced with Feature 16 integration)                    │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                    ┌────▼─────┐
                    │ Identify  │
                    │Transaction│
                    └────┬──────┘
                         │
    ┌────────────────────┴────────────────────┐
    │                                        │
┌───▼──────────────────────┐    ┌────────────▼──────────────┐
│ BankTransactionMatcher   │    │ ConfidenceScorer Service  │
│ (Enhanced matching logic)│    │ (NEW)                      │
│ - Amount fuzzing (±2%)  │    │ - Score calculation        │
│ - Date fuzzing (±3 days)│    │ - Threshold logic          │
│ - Customer name match   │    │ - ML confidence model      │
│ - Reference matching    │    └────────┬───────────────────┘
│ - Historical patterns   │             │
└───┬──────────────────────┘    ┌────────▼──────────┐
    │                           │ AutoPostingLogic  │
    └───────────────┬───────────┤ (NEW)             │
                    │           │ ≥95%: Auto-post  │
                    │           │ 85-94%: Suggest  │
                    │           │ <85%: Manual     │
                    │           └────────┬──────────┘
                    │                    │
    ┌───────────────▼────────────────────▼──────────┐
    │      PaymentAutoPostService (NEW)             │
    │  - Transaction matching + verification        │
    │  - Payment creation                           │
    │  - Invoice status update                      │
    │  - Audit trail logging                        │
    │  - SMS/email notification                     │
    │  - 1-hour rejection window handler            │
    └───────────────┬────────────────────────────────┘
                    │
    ┌───────────────▼───────────────────┐
    │      PaymentRejectionService      │
    │  (NEW - handles reversals)        │
    │  - Reversal intent processing     │
    │  - Auto-revert payment            │
    │  - ML feedback logging            │
    │  - Re-queue for manual            │
    └───────────────┬───────────────────┘
                    │
    ┌───────────────▼─────────────────┐
    │    Database Updates             │
    │  - Payments                     │
    │  - Invoices (status)            │
    │  - AutoPostAudit (NEW)          │
    │  - ConfidenceScores (NEW)       │
    │  - RejectionFeedback (NEW)      │
    └─────────────────────────────────┘
```

### 2.2 Service Architecture

#### **Service 1: ConfidenceScorerService**
Calculates confidence score for bank transaction matches.

```ruby
class ConfidenceScorerService
  # Inputs:
  # - transaction: BankFeedTransaction
  # - matching_invoice: Invoice (candidate)
  # - matching_payment_metadata: Hash (optional historical data)
  
  # Output: Result { success?, confidence_score (0-100), breakdown: Hash }
  
  def calculate_confidence
    # Component scoring:
    amount_score = score_amount_match(@transaction, @invoice)        # 0-30 pts
    date_score = score_date_match(@transaction, @invoice)            # 0-20 pts
    customer_score = score_customer_match(@transaction, @invoice)    # 0-25 pts
    reference_score = score_reference_match(@transaction, @invoice)  # 0-15 pts
    history_score = score_historical_accuracy                        # 0-10 pts
    
    # Total: 0-100
    confidence = (amount_score + date_score + customer_score + 
                  reference_score + history_score).round(2)
    
    # ML adjustment (optional): Apply learned thresholds
    confidence = apply_ml_adjustment(confidence, breakdown_hash)
    
    # Log for auditing
    log_confidence_breakdown(confidence, amount_score, date_score, ...)
    
    { success: true, confidence: confidence, breakdown: {...} }
  end
  
  private
  
  def score_amount_match(transaction, invoice)
    amount_diff = (transaction.amount - invoice.total).abs
    tolerance_pct = (amount_diff / invoice.total.to_f) * 100
    
    # 0% diff = 30 pts
    # ±2% diff = 25 pts
    # ±5% diff = 15 pts
    # >±5% diff = 0 pts
    return 30 if tolerance_pct == 0
    return 25 if tolerance_pct <= 2
    return 15 if tolerance_pct <= 5
    0
  end
  
  def score_date_match(transaction, invoice)
    date_diff = (transaction.date - invoice.issue_date).abs
    
    # Same day = 20 pts
    # ±1 day = 18 pts
    # ±3 days = 15 pts
    # >±3 days = 0 pts
    return 20 if date_diff == 0
    return 18 if date_diff <= 1
    return 15 if date_diff <= 3
    0
  end
  
  def score_customer_match(transaction, invoice)
    # Fuzzy string matching on customer name
    # Uses Levenshtein distance or similar
    similarity = fuzzy_match_score(
      transaction.customer_name,
      invoice.customer.name
    )
    
    # 100% match = 25 pts
    # 90%+ match = 20 pts
    # 80%+ match = 10 pts
    # <80% = 0 pts
    return 25 if similarity >= 1.0
    return 20 if similarity >= 0.90
    return 10 if similarity >= 0.80
    0
  end
  
  def score_reference_match(transaction, invoice)
    # Check if invoice number or order reference appears in transaction
    references = [invoice.invoice_number, invoice.order.order_number]
    match_found = references.any? { |ref| transaction.reference.include?(ref) }
    
    match_found ? 15 : 0
  end
  
  def score_historical_accuracy
    # ML component: Track successful matches vs. rejections
    # Build confidence adjustment based on historical data
    # For MVP: Fixed at 0, but structure supports future ML integration
    
    # TODO: Future - integrate with confidence_adjustments table
    0
  end
  
  def apply_ml_adjustment(base_confidence, breakdown)
    # Placeholder for ML integration
    # Will read learned thresholds from database
    base_confidence
  end
end
```

#### **Service 2: PaymentAutoPostService**
Handles auto-posting decision and execution.

```ruby
class PaymentAutoPostService
  # Inputs:
  # - bank_transaction: BankFeedTransaction
  # - confidence_score: Float (0-100)
  # - matching_invoice: Invoice
  # - configuration: Hash (confidence thresholds, etc.)
  
  # Output: Result { success?, action: Symbol, payment?: Payment, ... }
  
  def call
    score_result = confidence_check
    return score_result unless score_result.success?
    
    case score_result.data[:confidence]
    when 95..100
      auto_post_transaction(score_result.data)
    when 85..94
      create_suggestion(score_result.data)
    else
      route_to_manual_review(score_result.data)
    end
  end
  
  def auto_post_transaction(confidence_data)
    # Atomic transaction - all or nothing
    ActiveRecord::Base.transaction do
      # 1. Create Payment
      payment = Payment.create!(
        invoice: @matching_invoice,
        amount: @bank_transaction.amount,
        payment_method: 'bank_transfer',
        payment_date: @bank_transaction.date,
        reference_number: @bank_transaction.reference,
        confidence_score: confidence_data[:score],
        auto_posted: true,
        rejection_window_expires_at: 1.hour.from_now
      )
      
      # 2. Update Invoice
      @matching_invoice.update!(
        payment_received: true,
        amount_paid: @bank_transaction.amount,
        paid_at: Time.current
      )
      
      # 3. Create Audit Trail
      AutoPostAudit.create!(
        payment: payment,
        bank_transaction: @bank_transaction,
        confidence_breakdown: confidence_data[:breakdown],
        auto_posted: true,
        action: 'auto_posted',
        actor: 'system',
        timestamp: Time.current,
        audit_notes: "Auto-posted at #{confidence_data[:score]}% confidence"
      )
      
      # 4. Notify Finance & Customer
      notify_auto_post(payment, confidence_data)
      
      # 5. Schedule rejection window handler
      schedule_rejection_window_cleanup(payment)
      
      { ok: true, payment: payment, action: :auto_posted }
    end
  rescue ActiveRecord::RecordInvalid => e
    { ok: false, errors: e.message, action: :failed }
  end
  
  def create_suggestion(confidence_data)
    # Create as pending suggestion - requires manual approval
    suggestion = PaymentSuggestion.create!(
      bank_transaction: @bank_transaction,
      invoice: @matching_invoice,
      confidence_score: confidence_data[:score],
      confidence_breakdown: confidence_data[:breakdown],
      status: 'pending_approval'
    )
    
    # Notify Finance
    notify_payment_suggestion(suggestion)
    
    { ok: true, suggestion: suggestion, action: :suggestion_created }
  end
  
  def route_to_manual_review(confidence_data)
    # Create manual queue item
    manual_item = ManualPaymentReview.create!(
      bank_transaction: @bank_transaction,
      suggested_invoice: @matching_invoice,
      confidence_score: confidence_data[:score],
      reason: 'low_confidence',
      status: 'pending_review'
    )
    
    # Notify Finance - requires full manual review
    notify_manual_review(manual_item)
    
    { ok: true, manual_item: manual_item, action: :routed_to_manual }
  end
  
  def schedule_rejection_window_cleanup(payment)
    # Use Sidekiq to check if payment was rejected after 1 hour
    RejectPaymentWindowJob.perform_at(
      1.hour.from_now,
      payment.id
    )
  end
  
  private
  
  def notify_auto_post(payment, confidence_data)
    # SMS to Finance lead: "Payment auto-posted for Invoice #{invoice.invoice_number}"
    # Email to Finance team with rejection link
    # SMS to Customer: "Payment of ₹#{payment.amount} received for Invoice #{invoice.invoice_number}"
  end
  
  def notify_payment_suggestion(suggestion)
    # SMS/Email to Finance: "Payment suggestion pending review"
  end
  
  def notify_manual_review(manual_item)
    # SMS/Email to Finance: "Payment requires manual review - confidence too low"
  end
end
```

#### **Service 3: PaymentRejectionService**
Handles payment rejection within 1-hour window.

```ruby
class PaymentRejectionService
  # Inputs:
  # - payment: Payment (auto-posted)
  # - rejection_reason: String (optional)
  # - actor: User
  
  # Output: Result { success?, payment?, errors? }
  
  def call
    # Validate rejection window
    return failure("Rejection window expired") if payment_window_expired?
    
    # Atomic reversal
    ActiveRecord::Base.transaction do
      # 1. Reverse Payment
      @payment.update!(
        status: 'reversed',
        reversed_at: Time.current,
        reversal_reason: @rejection_reason,
        reversed_by: @actor.id
      )
      
      # 2. Revert Invoice
      @payment.invoice.update!(
        payment_received: false,
        amount_paid: 0,
        paid_at: nil
      )
      
      # 3. Create Rejection Audit
      AutoPostAudit.create!(
        payment: @payment,
        bank_transaction: @payment.bank_transaction,
        auto_posted: false,
        action: 'rejected_by_finance',
        actor: @actor.id,
        timestamp: Time.current,
        audit_notes: @rejection_reason
      )
      
      # 4. Log ML Feedback
      RejectionFeedback.create!(
        payment: @payment,
        confidence_score: @payment.confidence_score,
        rejection_reason: @rejection_reason,
        timestamp: Time.current
      )
      
      # 5. Route to Manual Queue
      ManualPaymentReview.create!(
        bank_transaction: @payment.bank_transaction,
        suggested_invoice: @payment.invoice,
        confidence_score: @payment.confidence_score,
        reason: 'rejected_auto_post',
        status: 'pending_review'
      )
      
      # 6. Notify Finance
      notify_rejection(@payment)
      
      { ok: true, payment: @payment }
    end
  rescue => e
    { ok: false, errors: e.message }
  end
  
  private
  
  def payment_window_expired?
    Time.current > @payment.rejection_window_expires_at
  end
  
  def notify_rejection(payment)
    # SMS to Finance: "Payment #{payment.id} rejected - routed to manual review"
  end
end
```

---

## 3. Database Schema

### 3.1 New Tables

#### **Table: auto_post_audits**
```sql
CREATE TABLE auto_post_audits (
  id BIGSERIAL PRIMARY KEY,
  payment_id BIGINT REFERENCES payments(id),
  bank_transaction_id BIGINT REFERENCES bank_transactions(id),
  confidence_breakdown JSONB,  -- {amount: 25, date: 18, customer: 20, reference: 15, history: 0}
  auto_posted BOOLEAN,
  action VARCHAR(50),  -- 'auto_posted', 'rejected_by_finance', 'rejected_by_window'
  actor_id BIGINT REFERENCES users(id),
  timestamp TIMESTAMP,
  audit_notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_payment_id (payment_id),
  INDEX idx_bank_transaction_id (bank_transaction_id),
  INDEX idx_action (action),
  INDEX idx_timestamp (timestamp)
);
```

#### **Table: rejection_feedbacks**
```sql
CREATE TABLE rejection_feedbacks (
  id BIGSERIAL PRIMARY KEY,
  payment_id BIGINT REFERENCES payments(id),
  confidence_score FLOAT,
  rejection_reason VARCHAR(255),
  timestamp TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_payment_id (payment_id),
  INDEX idx_timestamp (timestamp)
);
```

#### **Table: confidence_adjustments** (ML Model)
```sql
CREATE TABLE confidence_adjustments (
  id BIGSERIAL PRIMARY KEY,
  amount_tolerance_pct FLOAT DEFAULT 2.0,
  date_tolerance_days INT DEFAULT 3,
  customer_fuzzy_minimum FLOAT DEFAULT 0.80,
  reference_weight INT DEFAULT 15,
  auto_post_threshold INT DEFAULT 95,
  suggestion_threshold INT DEFAULT 85,
  rejection_window_minutes INT DEFAULT 60,
  model_version INT DEFAULT 1,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE (model_version)
);
```

#### **Table: payment_suggestions** (For 85-94% range)
```sql
CREATE TABLE payment_suggestions (
  id BIGSERIAL PRIMARY KEY,
  bank_transaction_id BIGINT REFERENCES bank_transactions(id),
  invoice_id BIGINT REFERENCES invoices(id),
  confidence_score FLOAT,
  confidence_breakdown JSONB,
  status VARCHAR(50) DEFAULT 'pending_approval',  -- 'pending_approval', 'approved', 'rejected'
  approved_by BIGINT REFERENCES users(id),
  approved_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_status (status),
  INDEX idx_bank_transaction_id (bank_transaction_id),
  INDEX idx_invoice_id (invoice_id)
);
```

### 3.2 Enhanced Existing Tables

#### **Table: payments** (additions)
```sql
ALTER TABLE payments ADD COLUMN IF NOT EXISTS (
  auto_posted BOOLEAN DEFAULT FALSE,
  confidence_score FLOAT,
  rejection_window_expires_at TIMESTAMP,
  reversed_at TIMESTAMP,
  reversed_by BIGINT REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_payments_auto_posted 
  ON payments(auto_posted, rejection_window_expires_at);
```

#### **Table: bank_transactions** (additions if not exists)
```sql
ALTER TABLE bank_transactions ADD COLUMN IF NOT EXISTS (
  customer_name VARCHAR(255),
  reference VARCHAR(255),
  matched_confidence FLOAT,
  matched_invoice_id BIGINT REFERENCES invoices(id)
);

CREATE INDEX IF NOT EXISTS idx_bank_transactions_date 
  ON bank_transactions(date);
```

---

## 4. API Endpoints

### 4.1 Payment Auto-Posting Status Endpoint
```
GET /api/v1/payments/auto-posting-status
Authorization: Bearer <token>

Response 200:
{
  "auto_posting_enabled": true,
  "confidence_threshold_auto": 95,
  "confidence_threshold_suggest": 85,
  "rejection_window_minutes": 60,
  "stats": {
    "today_auto_posted": 12,
    "today_auto_post_success_rate": 0.98,
    "today_suggested": 3,
    "today_manual_review": 2
  }
}
```

### 4.2 Reject Auto-Posted Payment Endpoint
```
POST /api/v1/payments/:id/reject-auto-post
Authorization: Bearer <token>

Request Body:
{
  "rejection_reason": "Customer name mismatch",
  "notes": "Name doesn't match invoice"
}

Response 200:
{
  "ok": true,
  "payment": {
    "id": 123,
    "status": "reversed",
    "reversed_at": "2026-03-17T10:30:00Z",
    "invoice_id": 456
  },
  "message": "Payment reversed and routed to manual review"
}

Response 422:
{
  "ok": false,
  "error": "Rejection window expired (>1 hour)"
}
```

### 4.3 Get Confidence Score Explanation Endpoint
```
GET /api/v1/payments/:id/confidence-breakdown
Authorization: Bearer <token>

Response 200:
{
  "payment_id": 123,
  "confidence_score": 97.5,
  "breakdown": {
    "amount_match": {"score": 30, "value": "Exact match (₹10,000)"}, 
    "date_match": {"score": 20, "value": "Same day"},
    "customer_name": {"score": 20, "value": "95% fuzzy match"},
    "reference_match": {"score": 15, "value": "Invoice number in reference"},
    "historical": {"score": 12.5, "value": "Customer payment history +2.5%"}
  },
  "auto_posted": true,
  "can_reject_until": "2026-03-17T11:30:00Z"
}
```

### 4.4 Get Auto-Posting Audit Trail
```
GET /api/v1/auto-post-audits?filters[status]=auto_posted&filters[date_from]=2026-03-01&limit=50
Authorization: Bearer <token>

Response 200:
{
  "audits": [
    {
      "id": 1,
      "payment_id": 123,
      "action": "auto_posted",
      "confidence_score": 97.5,
      "timestamp": "2026-03-17T10:00:00Z",
      "actor": "system",
      "notes": "Auto-posted at 97.5% confidence"
    },
    ...
  ],
  "total": 145,
  "page": 1,
  "per_page": 50
}
```

---

## 5. Test Specifications

### 5.1 Test Suite Structure

**70+ Test Cases across 6 test files:**

#### **File 1: ConfidenceScorerService Spec** (20 tests)
```ruby
require 'rails_helper'

describe ConfidenceScorerService do
  let(:transaction) { create(:bank_transaction) }
  let(:invoice) { create(:invoice) }
  
  describe '#calculate_confidence' do
    # Test Groups:
    # 1. Amount Score (5 tests)
    #    - Exact match: 30 points
    #    - ±1% diff: 25 points
    #    - ±5% diff: 15 points
    #    - >5% diff: 0 points
    #    - Negative amount handling
    
    # 2. Date Score (4 tests)
    #    - Same day: 20 points
    #    - ±1 day: 18 points
    #    - ±3 days: 15 points
    #    - >3 days: 0 points
    
    # 3. Customer Match (4 tests)
    #    - Exact name: 25 points
    #    - 90%+ fuzzy: 20 points
    #    - 80%+ fuzzy: 10 points
    #    - <80% fuzzy: 0 points
    
    # 4. Reference Match (3 tests)
    #    - Invoice number in reference: 15 points
    #    - Order number in reference: 15 points
    #    - No match: 0 points
    
    # 5. Composite Scoring (4 tests)
    #    - Perfect match (all 100): 100 score
    #    - High confidence (80+): 85+ total
    #    - Medium confidence: 85 points
    #    - Low confidence: <85 points
  end
end
```

#### **File 2: PaymentAutoPostService Spec** (25 tests)
```ruby
require 'rails_helper'

describe PaymentAutoPostService do
  let(:transaction) { create(:bank_transaction) }
  let(:invoice) { create(:invoice, total: 10000) }
  
  describe '#call' do
    # Test Groups:
    # 1. Confidence ≥95% (8 tests)
    #    - Creates payment with auto_posted=true
    #    - Sets rejection_window_expires_at to 1 hour from now
    #    - Updates invoice payment_received=true
    #    - Creates auto_post_audit entry
    #    - Sends SMS notification to Finance
    #    - Sends SMS notification to Customer
    #    - Schedules rejection window job
    #    - Idempotent (calling twice doesn't duplicate)
    
    # 2. Confidence 85-94% (6 tests)
    #    - Creates PaymentSuggestion with status=pending_approval
    #    - Does NOT create Payment record
    #    - Sends SMS to Finance for suggestion
    #    - Stores confidence_breakdown JSON
    #    - Returns action: :suggestion_created
    #    - Timestamp matches Time.current
    
    # 3. Confidence <85% (5 tests)
    #    - Routes to ManualPaymentReview
    #    - Sets reason=low_confidence
    #    - Does NOT create Payment
    #    - Sends SMS to Finance: "Manual review required"
    #    - Returns action: :routed_to_manual
    
    # 4. Transaction Failures (3 tests)
    #    - Invoice not found: returns error
    #    - Duplicate payment attempt: handles gracefully
    #    - Database connection error: transaction rolls back
    
    # 5. Audit Trail (3 tests)
    #    - AutoPostAudit created for auto_posted
    #    - AutoPostAudit stores confidence_breakdown
    #    - Timeline flags as "auto_posted" with timestamp
  end
  
  describe '#schedule_rejection_window_cleanup' do
    # 2 tests:
    # - Schedules RejectPaymentWindowJob for 1 hour from now
    # - Job ID is stored for tracking
  end
end
```

#### **File 3: PaymentRejectionService Spec** (15 tests)
```ruby
require 'rails_helper'

describe PaymentRejectionService do
  let(:payment) { create(:payment, auto_posted: true, rejection_window_expires_at: 1.hour.from_now) }
  let(:user) { create(:user, role: :finance) }
  
  describe '#call' do
    # Test Groups:
    # 1. Successful Rejection (6 tests)
    #    - Updates payment status to 'reversed'
    #    - Sets reversed_at timestamp
    #    - Sets reversed_by to actor ID
    #    - Updates invoice payment_received=false
    #    - Creates AutoPostAudit with action: 'rejected_by_finance'
    #    - Creates RejectionFeedback for ML learning
    
    # 2. Window Expiration (3 tests)
    #    - Rejects if window expired
    #    - Returns error message "Rejection window expired"
    #    - Does NOT reverse payment
    
    # 3. Error Handling (3 tests)
    #    - Invoice not found: gracefully handles
    #    - User not found: uses system actor
    #    - Database error: transaction rolls back
    
    # 4. Notification (2 tests)
    #    - Sends SMS to Finance: payment reversed
    #    - Creates ManualPaymentReview for re-routing
    
    # 5. Audit Trail (1 test)
    #    - RejectionFeedback stores confidence_score + reason
  end
end
```

#### **File 4: Integration Spec** (12 tests)
```ruby
require 'rails_helper'

describe 'Bank Auto-Posting Workflow' do
  # Test Groups:
  # 1. End-to-End High Confidence (2 tests)
  #    - Bank transaction → Confidence 97% → Auto-post → Payment created
  #    - Rejection within window → Payment reversed → Manual queue
  
  # 2. End-to-End Medium Confidence (2 tests)
  #    - Bank transaction → Confidence 90% → Suggestion created
  #    - Finance approves suggestion → Payment created
  
  # 3. End-to-End Low Confidence (2 tests)
  #    - Bank transaction → Confidence 75% → Manual queue
  #    - Finance reviews → Manually approves → Payment created
  
  # 4. Edge Cases (6 tests)
  #    - Duplicate transaction detection
  #    - Late transaction posting (>10 days old)
  #    - Multiple matches for same invoice
  #    - Amount mismatch >5%
  #    - Partial payment scenario
  #    - Customer name completely different
end
```

#### **File 5: API Endpoint Spec** (10 tests)
```ruby
require 'rails_helper'

describe 'POST /api/v1/payments/:id/reject-auto-post' do
  # 5 tests:
  # - Valid rejection with reason: 200 OK
  # - Expired rejection window: 422 error
  # - Missing rejection_reason: validates (optional or required?)
  # - Unauthorized user: 401 error
  # - Payment not auto-posted: 422 error (can't reject manual)
end

describe 'GET /api/v1/payments/:id/confidence-breakdown' do
  # 5 tests:
  # - Returns confidence score breakdown
  # - Shows component scores (amount, date, customer, reference)
  # - Shows historical adjustment if applied
  # - Includes can_reject_until timestamp
  # - Returns 404 if payment not found
end
```

#### **File 6: ML Feedback & Learning Spec** (8 tests)
```ruby
require 'rails_helper'

describe 'ML Feedback Loop' do
  # Test Groups:
  # 1. Rejection Feedback Logging (3 tests)
  #    - RejectionFeedback created on payment reversal
  #    - Stores confidence_score + rejection_reason
  #    - Used for retraining confidence thresholds
  
  # 2. False Positive Tracking (3 tests)
  #    - Tracks confidence scores of rejected transactions
  #    - Identifies patterns (e.g., all rejections at 92-95% range)
  #    - Dashboard shows false positive rate
  
  # 3. Model Version Management (2 tests)
  #    - confidence_adjustments stores model version
  #    - Version increments on threshold update
  #    - Old versions preserved for audit
end
```

---

## 6. Implementation Plan

### Phase 1: Foundation (Days 1-3, ~15 hours)
- [ ] Create database migrations (4 new tables, 2 table enhancements)
- [ ] Implement ConfidenceScorerService (20 component tests)
- [ ] Create test data factories for BankTransaction, PaymentSuggestion
- [ ] Run database syntax validation

### Phase 2: Core Services (Days 4-7, ~20 hours)
- [ ] Implement PaymentAutoPostService (25 integration tests)
- [ ] Implement PaymentRejectionService (15 tests)
- [ ] Create AutoPostAudit & RejectionFeedback models
- [ ] Implement rejection window scheduling job (RejectPaymentWindowJob)

### Phase 3: API Layer (Days 8-10, ~15 hours)
- [ ] Create PaymentController enhancements (4 new endpoints)
- [ ] Implement API response serializers
- [ ] Add authorization checks (Finance role required)
- [ ] Write 10 API endpoint tests

### Phase 4: Integration & Testing (Days 11-13, ~10 hours)
- [ ] Integration tests (12 workflow tests)
- [ ] ML feedback loop structure (8 tests)
- [ ] Dashboard stats aggregation
- [ ] End-to-end scenario testing

### Phase 5: Documentation & Deployment (Days 14, ~5 hours)
- [ ] API documentation (Swagger/OpenAPI)
- [ ] Configuration guide (thresholds, window duration)
- [ ] Runbook for Finance team
- [ ] Training materials for operations team

---

## 7. Configuration & Deployment

### 7.1 Environment Configuration

```yaml
# config/feature_flags.yml
features:
  bank_auto_posting:
    enabled: true
    confidence_threshold_auto: 95      # Auto-post if ≥95%
    confidence_threshold_suggest: 85   # Suggest if 85-94%
    rejection_window_minutes: 60       # Finance has 60 min to reject
    
    # Scoring tolerances
    amount_tolerance_pct: 2.0          # ±2% fuzzy match
    date_tolerance_days: 3             # ±3 days fuzzy match
    customer_fuzzy_minimum: 0.80       # 80%+ similarity
    reference_weight: 15               # Points for reference match
    
    # Notifications
    notify_finance_sms: true
    notify_customer_sms: true
    sms_gateway: 'twilio'              # or 'sns', 'custom'
    
    # ML Configuration
    enable_confidence_learning: false  # Phase 3.2 enhancement
    ml_model_update_frequency: 'weekly'
    
    # Audit
    audit_retention_months: 36         # Keep audit trail for 3 years
    audit_sqs_queue: 'bank-autopost-audit'  # For compliance reporting
```

### 7.2 Gradual Rollout Strategy

```
Week 1 (March 17-23):
  - Deploy to staging environment
  - Run full test suite (70+ tests)
  - Internal testing with Finance team
  - Confidence threshold: DISABLED (suggest only)

Week 2 (March 24-30):
  - Deploy to production with feature flag DISABLED
  - Notify Finance team of new endpoints
  - Manual dry-run (no real auto-posting)
  - Collect baseline data on suggestion accuracy

Week 3-4 (March 31 - April 13):
  - Enable 50% of transactions (random split)
  - Monitor false positive rate (<2% target)
  - Collect rejection feedback
  - Adjust threshold if needed (currently 95%)

Week 5+ (April 14+):
  - Enable 100% of transactions ≥95% confidence
  - Monitor daily: auto-post rate, false positives, rejections
  - Prepare for ML learning phase (Phase 3.2)
```

---

## 8. Monitoring & Success Metrics

### 8.1 Dashboards
- **Auto-Posting Status Dashboard**
  - Today: 12 auto-posted, 98% success rate
  - Today: 3 suggestions, 2 manual reviews
  - This week: 65 auto-posted, 1 rejection
  - This month: 280 auto-posted, <1% false positive

- **Confidence Score Distribution**
  - 0-50%: 5% of transactions (manual)
  - 50-85%: 15% of transactions (suggestions)
  - 85-95%: 35% of transactions (suggestions)
  - 95-100%: 45% of transactions (auto-posted)

### 8.2 Alerting
- **Alert: High Rejection Rate** (>2% of auto-posted in last 24h)
- **Alert: Confidence Scoring Anomaly** (mean confidence dropped >10%)
- **Alert: Rejection Window Job Failure** (failed to process within 1 hour)
- **Alert: System Processing Lag** (transactions not scored within 10 minutes)

### 8.3 ROI Tracking
- **Week 3-4**: Baseline - Manual review takes 2-3 min per transaction
- **Week 5+**: Measured savings = (auto_posted_count × 2.5 min) + (suggestions_approved × 1.5 min)
  - Example: 45% auto + 35% suggested = 50-120 min/week saved
  - Target: 85-120 min/week by end of April

---

## 9. Risk Mitigation

### Risk 1: False Positives in Auto-Posting
**Risk**: Auto-post at 95% confidence but still match wrong invoice (wrong customer)

**Mitigation**:
- Customer name fuzzy matching requires 80%+ similarity (prevents typo matches)
- Reference number match provides +15 pts (high weight)
- 1-hour rejection window allows Finance to catch errors
- Audit trail fully logged for review

**Monitoring**: Track rejection rate by confidence band - if 95-99% band has >2% rejections, lower threshold to 97%

### Risk 2: Late Transaction Processing
**Risk**: Bank feed has delays, transaction arrives days late, confidence score already aged

**Mitigation**:
- Date tolerance set to ±3 days (covers typical bank processing delays)
- Transactions >10 days old flagged for manual review (escalation)
- Timestamp both transaction date and processing date in audit

### Risk 3: ML Threshold Drift
**Risk**: Historical accuracy feedback could lead to overly confident auto-posting

**Mitigation**:
- Phase 1 disables ML learning (manual threshold control)
- Phase 3.2 adds approval gate before applying new thresholds
- Maintain human-set baseline (95%) as safety floor
- Weekly review of threshold changes by Finance Manager + Technical Lead

---

## 10. Future Enhancements (Phase 3.2+)

1. **ML Confidence Learning**
   - Analyze RejectionFeedback data
   - Identify patterns where confidence score was too high/low
   - Auto-adjust thresholds monthly (with human approval)

2. **Multi-Invoice Matching**
   - Handle scenarios where bank transfer covers multiple invoices
   - Split confidence scoring

3. **Transaction Categorization**
   - Classify transaction type (customer payment, refund, reversal, etc.)
   - Adjust confidence scoring by type

4. **Supplier Payment Auto-Posting**
   - Extend framework to outbound payments (accounts payable)
   - Similar confidence scoring for vendor payments

---

## 11. Appendix: Code Examples

### Code Example: Minimal Service Call
```ruby
# In BankTransactionProcessor or similar
transaction = BankTransaction.find(transaction_id)

# Get confidence score
scorer = ConfidenceScorerService.new(
  transaction: transaction,
  matching_invoice: invoice
)
score_result = scorer.calculate_confidence

if score_result.success?
  # Auto-post or create suggestion based on score
  autoposter = PaymentAutoPostService.new(
    bank_transaction: transaction,
    confidence_score: score_result.data[:confidence],
    matching_invoice: invoice,
    configuration: {}
  )
  result = autoposter.call
  
  if result.ok?
    # Payment created (auto-posted or suggested)
    logger.info("Transaction processed: #{result.action}")
  else
    logger.error("Failed to process transaction: #{result.errors}")
  end
end
```

### Code Example: Rejection Handler
```ruby
# In API Controller
@payment = Payment.find(params[:id])

rejector = PaymentRejectionService.new(
  payment: @payment,
  rejection_reason: params[:rejection_reason],
  actor: current_user
)

result = rejector.call

if result.ok?
  render json: { ok: true, payment: result.payment }, status: 200
else
  render json: { ok: false, error: result.errors }, status: 422
end
```

---

## 12. Sign-Off

**Document Status**: READY FOR IMPLEMENTATION  
**Review Date**: March 17, 2026  
**Next Step**: Proceed with Phase 1 (Database + ConfidenceScorerService)  
**Expected Completion**: April 1, 2026 (2 weeks)  

