# PostgreSQL Installation for Feature 16 Testing - Windows Quick Start

**Status**: PostgreSQL not found on system  
**Required for**: Phase 3 RSpec test execution (145+ tests)  
**Time to Install**: 15-30 minutes  

---

## Option 1: Quick Installation (Recommended)

### Step 1: Download PostgreSQL Installer
1. Go to: https://www.postgresql.org/download/windows/
2. Click "Download the installer"
3. Download PostgreSQL 15 or later
4. Run the installer (e.g., `postgresql-15.x-x64.exe`)

### Step 2: Installation Wizard
When prompted:
- **Installation Directory**: Accept default or choose custom
- **Components**: Select all components (including pgAdmin 4)
- **Data Directory**: Accept default
- **Port**: Keep default (5432)
- **Superuser Password**: Remember this! (e.g., `postgres`)
- **Service Name**: Accept default
- **Launch Stack Builder**: NO (uncheck)

### Step 3: Verify Installation
```powershell
psql --version
```

Expected output: `psql (PostgreSQL) 15.x`

### Step 4: Create Test Database
```powershell
# Open PowerShell and run:
psql -U postgres -c "CREATE DATABASE backend_test ENCODING 'UTF8' TEMPLATE template0;"

# When prompted, enter the password you set during installation
```

### Step 5: Verify Database Created
```powershell
psql -U postgres -l
# Look for "backend_test" in the list
```

---

## Option 2: Automated Installation (Windows)

### Using Chocolatey (if installed)
```powershell
# Install PostgreSQL via Chocolatey
choco install postgresql15 --params '/Password:postgres'

# Create test database
psql -U postgres -c "CREATE DATABASE backend_test ENCODING 'UTF8' TEMPLATE template0;"
```

### Manual Setup Script
Create file: `setup_postgres.ps1`

```powershell
# setup_postgres.ps1
param(
    [string]$Password = "postgres"
)

Write-Host "Setting up PostgreSQL for Feature 16 testing..." -ForegroundColor Green

# Check if PostgreSQL is installed
try {
    $pgVersion = psql --version
    Write-Host "✓ PostgreSQL found: $pgVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ PostgreSQL not found. Please install from https://www.postgresql.org/download/windows/" -ForegroundColor Red
    exit 1
}

# Create test database
Write-Host "Creating backend_test database..." -ForegroundColor Yellow
psql -U postgres -c "CREATE DATABASE backend_test ENCODING 'UTF8' TEMPLATE template0;" 2>$null

# Verify
Write-Host "Verifying database..." -ForegroundColor Yellow
$output = psql -U postgres -l | Select-String "backend_test"
if ($output) {
    Write-Host "✓ Database 'backend_test' created successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to create database" -ForegroundColor Red
    exit 1
}

Write-Host "Setup complete! Ready to run tests." -ForegroundColor Green
```

Run with:
```powershell
.\setup_postgres.ps1 -Password "postgres"
```

---

## Option 3: Add PostgreSQL to PATH (if installation doesn't auto-add)

If `psql` command is not found after installation:

1. Find PostgreSQL bin folder (usually: `C:\Program Files\PostgreSQL\15\bin`)
2. Add to PATH:
   ```powershell
   # Run in PowerShell as Administrator:
   $env:Path += ";C:\Program Files\PostgreSQL\15\bin"
   
   # Make permanent:
   [Environment]::SetEnvironmentVariable("Path", "$env:Path;C:\Program Files\PostgreSQL\15\bin", "User")
   ```

3. Restart PowerShell and test:
   ```powershell
   psql --version
   ```

---

## Verify PostgreSQL is Running

```powershell
# Check if PostgreSQL service is running
Get-Service PostgreSQL*

# If not running, start it:
Start-Service postgresql-x64-15  # (adjust version number as needed)
```

---

## Test Database Connection

```powershell
# Connect to test database
psql -U postgres -d backend_test -c "SELECT 1;"

# Expected output:
# ?column?
# ----------
#        1
# (1 row)
```

---

## Next Steps After Installation

Once PostgreSQL is installed and test database is created:

```powershell
# 1. Navigate to backend directory
cd c:\Users\chitr\Projects\orderlane_pro\backend

# 2. Create database (idempotent - safe to run again)
$env:RAILS_ENV = "test"
bundle exec rails db:create

# 3. Run migrations
bundle exec rails db:migrate

# 4. Verify migrations
bundle exec rails db:migrate:status
# Look for: 20260317000004  Add bank auto posting tables  up

# 5. Run all Feature 16 tests
bundle exec rspec spec/services/payments/ `
  spec/integration/ `
  spec/requests/api/v1/payments/auto_posting_spec.rb `
  spec/models/bank_auto_posting_models_spec.rb `
  spec/system/bank_auto_posting_system_stats_spec.rb `
  --format progress

# 6. Generate coverage report
bundle exec rspec spec/services/payments/ `
  spec/integration/ `
  spec/requests/api/v1/payments/ `
  spec/models/bank_auto_posting_models_spec.rb `
  spec/system/bank_auto_posting_system_stats_spec.rb `
  --format html --out coverage/rspec.html

# 7. View coverage
start coverage\rspec.html
```

---

## Troubleshooting

### Issue: "psql: command not found"
**Solution**: Add PostgreSQL bin folder to PATH (see Option 3 above)

### Issue: "FATAL: password authentication failed"
**Solution**: 
```powershell
# Use psql without password prompt:
psql -U postgres -h localhost <<EOF
ALTER USER postgres WITH PASSWORD 'newpassword';
\q
EOF
```

### Issue: "Port 5432 already in use"
**Solution**:
```powershell
# Check what's using the port
netstat -ano | findstr :5432

# Either stop that service or use different port in database.yml
# (then update RAILS_ENV_DATABASE_PORT)
```

### Issue: "database backend_test already exists"
**Solution**: This is safe to ignore. Database creation is idempotent:
```powershell
bundle exec rails db:create
# Will skip if database already exists
```

---

## Verify Everything is Ready

Before running tests, run this verification script:

```powershell
Write-Host "Feature 16 Test Readiness Check" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# 1. Check PostgreSQL
Write-Host "`n1. PostgreSQL Installation..." -ForegroundColor Yellow
try {
    $version = psql --version
    Write-Host "   ✓ $version" -ForegroundColor Green
} catch {
    Write-Host "   ✗ PostgreSQL not found" -ForegroundColor Red
    exit 1
}

# 2. Check backend_test database
Write-Host "`n2. Test Database..." -ForegroundColor Yellow
try {
    $result = psql -U postgres -d backend_test -c "SELECT 1;" 2>$null
    Write-Host "   ✓ backend_test database accessible" -ForegroundColor Green
} catch {
    Write-Host "   ✗ backend_test database not accessible" -ForegroundColor Red
    exit 1
}

# 3. Check Ruby/Gems
Write-Host "`n3. Ruby Environment..." -ForegroundColor Yellow
try {
    $rubyVersion = ruby --version
    Write-Host "   ✓ $rubyVersion" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Ruby not found" -ForegroundColor Red
    exit 1
}

# 4. Check Bundler
Write-Host "`n4. Bundler..." -ForegroundColor Yellow
try {
    bundle --version | Out-Null
    Write-Host "   ✓ Bundler installed" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Bundler not found" -ForegroundColor Red
    exit 1
}

# 5. Check Rails
Write-Host "`n5. Rails Environment..." -ForegroundColor Yellow
try {
    cd c:\Users\chitr\Projects\orderlane_pro\backend
    bundle exec rails --version | Out-Null
    Write-Host "   ✓ Rails environment ready" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Rails environment issue" -ForegroundColor Red
    exit 1
}

# 6. Check Test Files
Write-Host "`n6. Test Files..." -ForegroundColor Yellow
$testFiles = @(
    "spec/services/payments/confidence_scorer_service_spec.rb",
    "spec/services/payments/payment_auto_post_service_integration_spec.rb",
    "spec/integration/feature_16_bank_auto_posting_workflow_spec.rb",
    "spec/requests/api/v1/payments/auto_posting_spec.rb",
    "spec/models/bank_auto_posting_models_spec.rb",
    "spec/system/bank_auto_posting_system_stats_spec.rb"
)

$allFound = $true
foreach ($file in $testFiles) {
    if (Test-Path $file) {
        Write-Host "   ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Missing: $file" -ForegroundColor Red
        $allFound = $false
    }
}

Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
if ($allFound) {
    Write-Host "✓ All systems ready! Run tests with:" -ForegroundColor Green
    Write-Host "  bundle exec rspec spec/services/payments/ ..." -ForegroundColor Cyan
} else {
    Write-Host "✗ Some files missing. Check test file setup." -ForegroundColor Red
}
```

---

## Installation Checklist

After PostgreSQL installation, verify each step:

- [ ] Downloaded PostgreSQL 15+ installer
- [ ] Ran installer (default settings fine)
- [ ] `psql --version` returns version number
- [ ] Found PostgreSQL service in Services
- [ ] Created backend_test database
- [ ] `psql -U postgres -d backend_test -c "SELECT 1;"` succeeds
- [ ] Rails can create test database: `bundle exec rails db:create RAILS_ENV=test`
- [ ] Rails migrations run: `bundle exec rails db:migrate RAILS_ENV=test`
- [ ] Migration 20260317000004 shows "up" in `bundle exec rails db:migrate:status`

Once all items checked, you're ready to run the 145+ RSpec tests!

---

## Quick Reference Commands

```powershell
# After PostgreSQL is installed:

# 1. Create test database (one-time)
psql -U postgres -c "CREATE DATABASE backend_test ENCODING 'UTF8' TEMPLATE template0;"

# 2. Prepare Rails for testing
cd c:\Users\chitr\Projects\orderlane_pro\backend
$env:RAILS_ENV = "test"
bundle exec rails db:create
bundle exec rails db:migrate

# 3. Run all tests
bundle exec rspec spec/services/payments/ spec/integration/ spec/requests/api/v1/payments/auto_posting_spec.rb spec/models/bank_auto_posting_models_spec.rb spec/system/bank_auto_posting_system_stats_spec.rb --format progress

# 4. View coverage
bundle exec rspec ... --format html --out coverage/rspec.html
start coverage\rspec.html
```

---

**Next Action**: Install PostgreSQL from https://www.postgresql.org/download/windows/, then return here to run tests.

---

*Installation Guide Generated*: March 17, 2026  
*Phase*: 3 - Database Infrastructure Setup  
*Status*: Waiting for PostgreSQL installation
