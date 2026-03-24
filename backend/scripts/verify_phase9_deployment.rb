#!/usr/bin/env ruby
# ─────────────────────────────────────────────────────────────────────────────
# DEPLOYMENT VERIFICATION SCRIPT - Phase 9 Changes
# Purpose: Verify all Phase 9 components are ready for production deployment
# Date: March 24, 2026
# ─────────────────────────────────────────────────────────────────────────────

require 'fileutils'
require 'json'

class DeploymentVerifier
  CHECKS = [
    { name: "Database Schema", method: :check_database },
    { name: "Migrations", method: :check_migrations },
    { name: "Models & Associations", method: :check_models },
    { name: "Jobs & Workers", method: :check_jobs },
    { name: "Services", method: :check_services },
    { name: "API Controllers", method: :check_controllers },
    { name: "Frontend Components", method: :check_frontend },
    { name: "Configuration", method: :check_config },
  ].freeze

  attr_reader :results

  def initialize
    @results = []
    @errors = []
  end

  def run_all_checks
    puts "\n" + "=" * 80
    puts "🔍 PHASE 9 DEPLOYMENT VERIFICATION"
    puts "=" * 80 + "\n"

    CHECKS.each do |check|
      result = send(check[:method])
      status = result[:passed] ? "✅" : "❌"
      puts "#{status} #{check[:name]}"
      
      if result[:details]
        result[:details].each { |detail| puts "   • #{detail}" }
      end

      @results << result
      puts
    end

    print_summary
  end

  private

  def check_database
    puts "   Checking database components..."

    checks = {
      "documents table exists" => check_file("backend/db/migrate/*001_create_documents.rb"),
      "Document model exists" => check_file("backend/app/models/document.rb"),
      "DocumentPolicy exists" => check_file("backend/app/policies/document_policy.rb"),
      "reference_id is bigint" => check_reference_id_type,
    }

    details = []
    passed = true

    checks.each do |name, result|
      if result
        details << "✓ #{name}"
      else
        details << "✗ #{name}"
        passed = false
      end
    end

    { passed:, details: }
  end

  def check_migrations
    puts "   Checking pending migrations..."

    # Check for any pending migrations
    output = `cd backend && bundle exec rake db:migrate:status 2>&1`
    
    if output.include?("no")
      { passed: true, details: ["✓ No pending migrations"] }
    else
      pending = output.scan(/\(\s*down\s*\)/).count
      if pending > 0
        {
          passed: false,
          details: ["✗ #{pending} pending migrations", "Run: bundle exec rake db:migrate"],
        }
      else
        { passed: true, details: ["✓ All migrations applied"] }
      end
    end
  rescue => e
    {
      passed: false,
      details: ["✗ Migration check failed: #{e.message}"],
    }
  end

  def check_models
    puts "   Checking models and associations..."

    checks = {
      "SalesInvoice callback" => check_sales_invoice_callback,
      "Document associations" => check_document_associations,
      "SalesInvoice has_many :documents" => check_file("backend/app/models/sales_invoice.rb", "has_many.*documents"),
    }

    details = []
    passed = true

    checks.each do |name, result|
      if result
        details << "✓ #{name}"
      else
        details << "✗ #{name}"
        passed = false
      end
    end

    { passed:, details: }
  end

  def check_jobs
    puts "   Checking Sidekiq jobs..."

    checks = {
      "GenerateInvoiceDocumentJob exists" => check_file("backend/app/jobs/generate_invoice_document_job.rb"),
      "Job has perform method" => check_file("backend/app/jobs/generate_invoice_document_job.rb", "def perform"),
      "Job configured with retry" => check_file("backend/app/jobs/generate_invoice_document_job.rb", "sidekiq_options"),
      "Job calls DocumentGeneratorService" => check_file("backend/app/jobs/generate_invoice_document_job.rb", "DocumentGeneratorService"),
    }

    details = []
    passed = true

    checks.each do |name, result|
      if result
        details << "✓ #{name}"
      else
        details << "✗ #{name}"
        passed = false
      end
    end

    { passed:, details: }
  end

  def check_services
    puts "   Checking document generation service..."

    checks = {
      "DocumentGeneratorService exists" => check_file("backend/app/services/document_generator_service.rb"),
      "generate_and_save method exists" => check_file("backend/app/services/document_generator_service.rb", "def generate_and_save"),
      "Handles reference_id parameter" => check_file("backend/app/services/document_generator_service.rb", "reference_id"),
      "TYPES validation fixed" => check_file("backend/app/services/document_generator_service.rb", "TYPES.keys.include"),
    }

    details = []
    passed = true

    checks.each do |name, result|
      if result
        details << "✓ #{name}"
      else
        details << "✗ #{name}"
        passed = false
      end
    end

    { passed:, details: }
  end

  def check_controllers
    puts "   Checking API controllers..."

    checks = {
      "DocumentsController exists" => check_file("backend/app/controllers/api/v1/documents_controller.rb"),
      "index action filters by reference_id" => check_file("backend/app/controllers/api/v1/documents_controller.rb", "for_reference"),
      "download action exists" => check_file("backend/app/controllers/api/v1/documents_controller.rb", "def download"),
      "generate action exists" => check_file("backend/app/controllers/api/v1/documents_controller.rb", "def generate"),
    }

    details = []
    passed = true

    checks.each do |name, result|
      if result
        details << "✓ #{name}"
      else
        details << "✗ #{name}"
        passed = false
      end
    end

    { passed:, details: }
  end

  def check_frontend
    puts "   Checking frontend components..."

    checks = {
      "Order detail page exists" => check_file("web/app/orders/[id]/page.tsx"),
      "DocumentsPanel component exists" => check_file("web/components/orders/order-documents-panel.tsx"),
      "Dual-query document fetching" => check_file("web/app/orders/[id]/page.tsx", "Fetching by order ID.*Fetching by invoice ID"),
      "Document deduplication" => check_file("web/app/orders/[id]/page.tsx", "uniqueDocuments"),
    }

    details = []
    passed = true

    checks.each do |name, result|
      if result
        details << "✓ #{name}"
      else
        details << "✗ #{name}"
        passed = false
      end
    end

    { passed:, details: }
  end

  def check_config
    puts "   Checking configurations..."

    checks = {
      "Sidekiq configured" => check_sidekiq_config,
      "DocumentPolicy defines access" => check_file("backend/app/policies/document_policy.rb", "def show"),
      "Routes include documents" => check_file("backend/config/routes.rb", "documents"),
    }

    details = []
    passed = true

    checks.each do |name, result|
      if result
        details << "✓ #{name}"
      else
        details << "✗ #{name}"
        passed = false
      end
    end

    { passed:, details: }
  end

  def print_summary
    puts "\n" + "=" * 80
    total = @results.length
    passed = @results.count { |r| r[:passed] }
    failed = total - passed

    if failed.zero?
      puts "✅ ALL CHECKS PASSED - Ready for deployment!"
    else
      puts "⚠️  #{failed}/#{total} checks failed - Review items above"
    end

    puts "=" * 80 + "\n"

    recommendations
  end

  def recommendations
    puts "📋 DEPLOYMENT CHECKLIST:"
    puts
    puts "Pre-Deployment (Run in development/staging):"
    puts "  [ ] bundle exec rake db:migrate"
    puts "  [ ] bundle exec rails runner 'GenerateInvoiceDocumentJob.new.perform(invoice_id)'"
    puts "  [ ] Verify /api/v1/documents endpoint returns data"
    puts
    puts "Deployment Steps:"
    puts "  [ ] Backup production database"
    puts "  [ ] Run migrations: bundle exec rake db:migrate RAILS_ENV=production"
    puts "  [ ] Deploy Phase 9 code"
    puts "  [ ] Restart Rails servers"
    puts "  [ ] Verify Sidekiq is processing jobs"
    puts "  [ ] Create test invoice and verify document generation"
    puts "  [ ] Monitor logs for errors"
    puts "  [ ] Verify order detail page shows documents"
    puts
    puts "Post-Deployment:"
    puts "  [ ] Monitor application logs"
    puts "  [ ] Test document download/preview"
    puts "  [ ] Verify no invoices missed"
    puts "  [ ] Check Sidekiq queue length"
    puts
  end

  # Helper methods

  def check_file(path, content_pattern = nil)
    # Try multiple possible locations
    possible_paths = [
      File.expand_path("../../../backend/#{path}", __FILE__),
      File.expand_path("../../../web/#{path}", __FILE__),
      File.expand_path(path),
    ]

    expanded_path = possible_paths.find { |p| File.exist?(p) && !File.directory?(p) }
    
    return false unless expanded_path && File.exist?(expanded_path)
    return true if content_pattern.nil?

    file_content = File.read(expanded_path)
    file_content.match?(/#{content_pattern}/m)
  rescue => e
    puts "      [Error checking #{path}: #{e.message}]"
    false
  end

  def check_reference_id_type
    # Check if documents table has reference_id column as bigint
    output = `cd backend && bundle exec rails runner "puts Document.columns_hash['reference_id'].sql_type" 2>&1`
    output.strip.include?("bigint")
  rescue
    false
  end

  def check_sales_invoice_callback
    content = File.read("backend/app/models/sales_invoice.rb")
    content.include?("after_commit :generate_invoice_document") &&
      content.include?("def generate_invoice_document") &&
      content.include?("GenerateInvoiceDocumentJob")
  rescue
    false
  end

  def check_document_associations
    content = File.read("backend/app/models/document.rb")
    content.include?("belongs_to :organization") &&
      content.include?("belongs_to :generated_by_user")
  rescue
    false
  end

  def check_sidekiq_config
    # Check if Sidekiq is configured in the app
    content = File.read("backend/config/initializers/sidekiq.rb") rescue ""
    content.include?("Sidekiq")
  rescue
    false
  end
end

# Run verification
verifier = DeploymentVerifier.new
verifier.run_all_checks
