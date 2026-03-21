# Feature 16: Phase 3 - Testing & Deployment Setup Guide

**Status**: In Progress  
**Phase**: 3 (Test Execution & Staging Preparation)  
**Date**: March 17, 2026

---

## Phase 3 Overview

Phase 3 consists of three main components:

1. **Database Setup** (Current)
   - Set up PostgreSQL for local testing
   - OR use Docker for isolated environment
   - Create and migrate test database

2. **RSpec Test Execution**
   - Run 145+ test cases
   - Generate coverage reports
   - Address any failures

3. **Staging Environment Preparation**
   - Deploy code to staging
   - Configure feature flags
   - Set up monitoring

---

## Part 1: Database Setup

### Option A: Using Docker (Recommended)

#### Prerequisites
- Docker installed and running
- Docker Compose available

#### Steps

1. **Start PostgreSQL in Docker**:
```bash
cd backend
docker run --name orderlane_postgres \
  -e POSTGRES_DB=backend_test \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -d postgres:15
```

2. **Wait for container to be ready**:
```bash
# Wait ~5 seconds for PostgreSQL to start
sleep 5
```

3. **Verify connection**:
```bash
docker exec orderlane_postgres psql -U postgres -d backend_test -c "SELECT 1;"
```

#### Using Docker Compose (Simplified)

Create `docker-compose.yml` in backend directory:
```yaml
version: '3'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: backend_test
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Then:
```bash
docker-compose up -d
```

### Option B: Local PostgreSQL Installation

#### For Windows

1. **Download & Install PostgreSQL**:
   - Download from https://www.postgresql.org/download/windows/
   - Run installer
   - Remember the password you set for postgres user
   - Add bin folder to PATH

2. **Create test database**:
```powershell
psql -U postgres -c "CREATE DATABASE backend_test;"
```

3. **Update database.yml** (if needed):
```yaml
test:
  adapter: postgresql
  encoding: unicode
  database: backend_test
  username: postgres
  password: YOUR_PASSWORD_HERE
  host: localhost
  port: 5432
```

#### For macOS

```bash
# Install via Homebrew
brew install postgresql@15
brew services start postgresql@15

# Create test database
createdb backend_test
```

#### For Linux (Ubuntu/Debian)

```bash
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib
sudo -u postgres createdb backend_test
```

---

## Part 2: Database Migration

### Create and Migrate Test Database

```bash
cd backend

# Set test environment
$env:RAILS_ENV = "test"

# Create database (if not exists)
bundle exec rails db:create

# Run migrations
bundle exec rails db:migrate

# Verify migration
bundle exec rails db:migrate:status
```

#### Expected Migration Status

You should see the Feature 16 migration marked as "up":
```
database: backend_test

 Status   Migration ID    Migration Name
--------------------------------------------------
   up     20260317000004  Add bank auto posting tables
```

---

## Part 3: Running RSpec Tests

### Prerequisites Check

Before running tests, verify:

```bash
# 1. Database is running and accessible
psql -U postgres -d backend_test -c "SELECT 1;"

# 2. Gems are installed
bundle check

# 3. Database is migrated
bundle exec rails db:migrate:status
```

### Run All Feature 16 Tests

#### Option 1: Run All Tests (Fastest)
```bash
cd backend
bundle exec rspec \
  spec/services/payments/confidence_scorer_service_spec.rb \
  spec/services/payments/payment_auto_post_service_integration_spec.rb \
  spec/services/payments/payment_rejection_service_integration_spec.rb \
  spec/integration/feature_16_bank_auto_posting_workflow_spec.rb \
  spec/requests/api/v1/payments/auto_posting_spec.rb \
  spec/models/bank_auto_posting_models_spec.rb \
  spec/system/bank_auto_posting_system_stats_spec.rb \
  --format progress
```

#### Option 2: Run Tests with Detailed Output
```bash
bundle exec rspec \
  spec/services/payments/ \
  spec/integration/ \
  spec/requests/api/v1/payments/auto_posting_spec.rb \
  spec/models/bank_auto_posting_models_spec.rb \
  spec/system/bank_auto_posting_system_stats_spec.rb \
  --format documentation
```

#### Option 3: Run Tests with Coverage Report
```bash
bundle exec rspec \
  spec/services/payments/ \
  spec/integration/ \
  spec/requests/api/v1/payments/ \
  spec/models/bank_auto_posting_models_spec.rb \
  spec/system/bank_auto_posting_system_stats_spec.rb \
  --format html \
  --out coverage/rspec.html
```

### Individual Test File Execution

```bash
# Unit tests only
bundle exec rspec spec/services/payments/confidence_scorer_service_spec.rb

# Integration tests
bundle exec rspec spec/services/payments/payment_auto_post_service_integration_spec.rb

# API tests
bundle exec rspec spec/requests/api/v1/payments/auto_posting_spec.rb

# Model tests
bundle exec rspec spec/models/bank_auto_posting_models_spec.rb

# System/Performance tests
bundle exec rspec spec/system/bank_auto_posting_system_stats_spec.rb
```

### Expected Test Results

**Total Tests**: 145+  
**Expected Results**:
- ✅ All tests should pass (100% pass rate)
- ⏱️ Execution time: 3-5 minutes (depending on system)
- 📊 Coverage target: >95%

#### Sample Output
```
ConfidenceScorerService
  ✓ calculates confidence correctly (20 tests)
  
PaymentAutoPostService
  ✓ routes based on confidence tiers (25+ tests)
  
PaymentRejectionService
  ✓ handles rejection window correctly (30+ tests)
  
Feature 16 Workflows
  ✓ completes end-to-end workflows (7 tests)
  
API Endpoints
  ✓ handles all 5 endpoints correctly (25+ tests)
  
Models
  ✓ validates all model associations (30+ tests)
  
System Stats
  ✓ calculates metrics accurately (40+ tests)

145+ examples, 0 failures
```

---

## Part 4: Troubleshooting

### Issue: "Connection refused" on Database

**Cause**: PostgreSQL not running

**Solution**:
```bash
# Docker:
docker start orderlane_postgres

# Docker Compose:
docker-compose up -d postgres

# Windows (service):
Get-Service PostgreSQL* | Start-Service

# macOS:
brew services start postgresql@15
```

### Issue: "Database 'backend_test' does not exist"

**Solution**:
```bash
bundle exec rails db:create
bundle exec rails db:migrate
```

### Issue: "Password authentication failed"

**Solution**: Check database.yml credentials match your PostgreSQL setup:
```bash
# Reset PostgreSQL password on Windows
psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'your_password';"
```

### Issue: "Uninitialized constant" in test

**Cause**: Model file not created

**Solution**: Verify all model files exist:
```bash
# Check if model files exist
ls -la app/models/auto_post_audit.rb
ls -la app/models/rejection_feedback.rb
ls -la app/models/confidence_adjustment.rb
ls -la app/models/payment_suggestion.rb
```

### Issue: "Factory already registered"

**Cause**: Duplicate factory definitions (FIXED in Phase 2)

**Solution**: Already handled - bank_transaction factory removed from bank_auto_posting.rb

---

## Part 5: Cleanup & Database Reset

### Reset Test Database (if needed)

```bash
# Remove test database and recreate
bundle exec rails db:drop RAILS_ENV=test
bundle exec rails db:create RAILS_ENV=test
bundle exec rails db:migrate RAILS_ENV=test
```

### Stop Docker Services

```bash
# Stop PostgreSQL container
docker stop orderlane_postgres

# Remove container
docker rm orderlane_postgres

# Or with Docker Compose:
docker-compose down
```

---

## Part 6: Continuous Integration Setup (Optional)

### Test Automation Script

Create `run_tests.sh`:
```bash
#!/bin/bash
set -e

echo "🚀 Starting Feature 16 Test Suite..."

# Start database if using Docker
docker start orderlane_postgres || true
sleep 2

# Install dependencies
bundle install

# Prepare database
bundle exec rails db:create RAILS_ENV=test || true
bundle exec rails db:migrate RAILS_ENV=test

# Run tests
echo "📝 Running tests..."
bundle exec rspec \
  spec/services/payments/ \
  spec/integration/ \
  spec/requests/api/v1/payments/auto_posting_spec.rb \
  spec/models/bank_auto_posting_models_spec.rb \
  spec/system/bank_auto_posting_system_stats_spec.rb \
  --format progress

echo "✅ All tests completed successfully!"
```

Make executable and run:
```bash
chmod +x run_tests.sh
./run_tests.sh
```

---

## Part 7: Test Execution Checklist

Before running full test suite:

- [ ] PostgreSQL is installed and running
- [ ] Django database is created
- [ ] `bundle install` executed successfully
- [ ] `bundle exec rails db:create` succeeded
- [ ] `bundle exec rails db:migrate` succeeded (shows migration 20260317000004)
- [ ] All model files exist in app/models/
- [ ] All service files exist in app/services/
- [ ] Factory files exist in spec/factories/
- [ ] Test files exist in spec/

### Quick Verification Script

```powershell
# Check all files exist
Write-Host "Checking files..."
$files = @(
  "app/services/payments/confidence_scorer_service.rb",
  "app/services/payments/payment_auto_post_service.rb",
  "app/services/payments/payment_rejection_service.rb",
  "app/models/auto_post_audit.rb",
  "app/models/rejection_feedback.rb",
  "app/models/confidence_adjustment.rb",
  "app/models/payment_suggestion.rb",
  "spec/services/payments/confidence_scorer_service_spec.rb",
  "spec/services/payments/payment_auto_post_service_integration_spec.rb",
  "spec/services/payments/payment_rejection_service_integration_spec.rb",
  "spec/integration/feature_16_bank_auto_posting_workflow_spec.rb",
  "spec/requests/api/v1/payments/auto_posting_spec.rb",
  "spec/models/bank_auto_posting_models_spec.rb",
  "spec/system/bank_auto_posting_system_stats_spec.rb"
)

foreach($file in $files) {
  if (Test-Path $file) {
    Write-Host "✓ $file"
  } else {
    Write-Host "✗ MISSING: $file"
  }
}

# Check database
Write-Host "`nChecking database..."
$env:RAILS_ENV = "test"
bundle exec rails db:migrate:status
```

---

## Part 8: Staging Environment Preparation

After tests pass, prepare staging:

### Staging Deployment Checklist

- [ ] All tests passing (145+ tests)
- [ ] Coverage > 95%
- [ ] Code review completed
- [ ] Database backup created
- [ ] Staging environment built
- [ ] Feature flag configured (false/disabled initially)
- [ ] Monitoring configured
- [ ] Finance team trained

### Feature Flag Setup

In `app/services/feature_flags.rb` or similar:

```ruby
class FeatureFlags
  def self.bank_auto_posting_enabled?
    # Initially disabled
    ENV.fetch('FEATURE_16_ENABLED', 'false') == 'true'
  end

  def self.bank_auto_posting_mode
    # Modes: disabled, observation, suggestion, gradual, production
    ENV.fetch('FEATURE_16_MODE', 'disabled')
  end
end
```

### Environment Variables

```bash
# Staging .env
FEATURE_16_ENABLED=true
FEATURE_16_MODE=observation

# Optional: Custom thresholds
FEATURE_16_AUTO_POST_THRESHOLD=95
FEATURE_16_SUGGESTION_THRESHOLD=85
FEATURE_16_REJECTION_WINDOW_MINUTES=60
```

---

## Part 9: Rollout Timeline

### Week 1: Observation Mode
- Status: Disabled in production
- Scoring: Runs in background only
- Data: Accumulating metrics

### Week 2: Suggestion Mode
- Status: Suggestions enabled (85%+)
- Auto-posting: Still disabled
- Finance approves suggestions

### Week 3-4: Gradual Rollout (50%)
- Status: 50% of matching transactions
- Auto-posting: For 95%+ confidence
- Monitoring: Continuous

### Week 5+: Full Production
- Status: 100% enabled
- Auto-posting: Standard workflow
- ML feedback: Collecting for improvements

---

## Next Steps

1. **Immediate** (Next session)
   - [ ] Set up PostgreSQL (Docker or local)
   - [ ] Create backend_test database
   - [ ] Run `rails db:migrate`
   - [ ] Execute full RSpec test suite

2. **Short-term** (Same day)
   - [ ] Address any test failures
   - [ ] Generate coverage report
   - [ ] Document results

3. **Medium-term** (Next session)
   - [ ] Deploy code to staging
   - [ ] Configure feature flags
   - [ ] Run internal testing
   - [ ] Finance team training

4. **Long-term** (Week 2-5)
   - [ ] Execute 5-week rollout plan
   - [ ] Monitor system performance
   - [ ] Collect ML feedback
   - [ ] Optimize thresholds

---

## Support Resources

### Useful Commands Reference

```bash
# Database
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:drop
bundle exec rails db:reset

# Testing
bundle exec rspec spec/
bundle exec rspec spec/ --format documentation
bundle exec rspec spec/ --format html --out coverage/rspec.html

# Rails console (testing)
$env:RAILS_ENV = "test"
bundle exec rails console

# Debugging specific test
bundle exec rspec spec/services/payments/confidence_scorer_service_spec.rb:42
```

### PostgreSQL Tips

```bash
# List databases
psql -U postgres -l

# Connect to test database
psql -U postgres -d backend_test

# Check table structure
\d auto_post_audits
\d rejection_feedbacks

# Count records
SELECT COUNT(*) FROM auto_post_audits;
```

---

**Status**: Ready for Database Setup  
**Next Action**: Set up PostgreSQL and execute test suite

---

*Report Generated: March 17, 2026*
