require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  add_filter '/db/'

  add_group 'Controllers', 'app/controllers'
  add_group 'Models',      'app/models'
  add_group 'Services',    'app/services'
  add_group 'Jobs',        'app/jobs'
  add_group 'Policies',    'app/policies'
  add_group 'Mailers',     'app/mailers'
  add_group 'Serializers', 'app/serializers'

  minimum_coverage 40 # Start low, ratchet up as coverage improves
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed
end
