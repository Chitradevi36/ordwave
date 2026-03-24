# frozen_string_literal: true

set :stage, :production
set :application, "ordwave"

# entire monorepo will be checked out here
set :deploy_to, "/home/deploy/apps/ordwave"

# commands must run inside backend/
set :app_subdir, "backend"

# bundler should use backend/Gemfile
set :bundle_gemfile, -> { release_path.join("backend", "Gemfile") }
set :bundle_path, -> { shared_path.join("bundle") }
set :bundle_without, %w[development test].join(" ")
set :bundle_flags, "--deployment"

set :rails_env, "production"

# shared files/dirs relative to repo root
append :linked_files,
       "backend/config/database.yml",
       "backend/config/master.key",
       "backend/.env.production"

append :linked_dirs,
       "backend/log",
       "backend/tmp/pids",
       "backend/tmp/cache",
       "backend/tmp/sockets",
       "backend/storage",
       "backend/public/system"

server "127.0.0.1",
  user: "deploy",
  roles: %w[app web db],
  primary: true

# service names on server
set :backend_puma_service, "ordwave_puma"
set :backend_sidekiq_service, "ordwave_sidekiq"