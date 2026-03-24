# frozen_string_literal: true

lock "~> 3.20.0"

set :repo_url, "git@github.com:Chitradevi36/orderlane_pro.git"
set :branch, ENV.fetch("BRANCH", "main")

# do not use pty as a workaround for RVM
set :pty, true

set :format, :airbrussh
set :format_options, truncate: false
set :log_level, :info

set :keep_releases, 5

# SSH
set :ssh_options, {
  user: "deploy",
  keys: %w[/home/deploy/.ssh/id_ed25519],
  forward_agent: false,
  auth_methods: %w[publickey]
}

# RVM
set :rvm_type, :user
set :rvm_ruby_version, "ruby-3.3.0"

# We are deploying a monorepo, but commands will run inside one subfolder per stage
set :app_subdir, nil

# shared dirs/files are stage-specific, so keep empty here
set :linked_files, []
set :linked_dirs, []

namespace :deploy do
  desc "Check that required variables are set"
  task :validate do
    on roles(:app) do
      required = %i[deploy_to app_subdir]
      required.each do |key|
        value = fetch(key)
        error "Missing required config: #{key}" if value.nil? || value.to_s.strip.empty?
      end
    end
  end
end

before "deploy:starting", "deploy:validate"

# Disable default Rails asset tasks (monorepo / API-only)
Rake::Task["deploy:assets:precompile"].clear_actions
Rake::Task["deploy:compile_assets"].clear_actions rescue nil