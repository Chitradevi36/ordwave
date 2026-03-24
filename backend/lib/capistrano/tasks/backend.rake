# frozen_string_literal: true

namespace :backend do
  def backend_path
    release_path.join(fetch(:app_subdir))
  end

  def current_backend_path
    current_path.join(fetch(:app_subdir))
  end

  desc "Upload database.yml if missing"
  task :check_shared do
    on roles(:app) do
      execute :mkdir, "-p", shared_path.join("backend/config")
      execute :mkdir, "-p", shared_path.join("backend/log")
      execute :mkdir, "-p", shared_path.join("backend/tmp/pids")
      execute :mkdir, "-p", shared_path.join("backend/tmp/cache")
      execute :mkdir, "-p", shared_path.join("backend/tmp/sockets")
      execute :mkdir, "-p", shared_path.join("backend/storage")
      execute :mkdir, "-p", shared_path.join("backend/public/system")
    end
  end

  desc "Bundle install for backend"
  task :bundle_install do
    on roles(:app) do
      within backend_path do
        with rails_env: fetch(:rails_env), bundle_gemfile: fetch(:bundle_gemfile) do
          execute :bundle, "config set path '#{fetch(:bundle_path)}'"
          execute :bundle, "config set without '#{fetch(:bundle_without)}'"
          execute :bundle, "install"
        end
      end
    end
  end

  desc "Run Rails db:migrate"
  task :migrate do
    on roles(:db) do
      within backend_path do
        with rails_env: fetch(:rails_env), bundle_gemfile: fetch(:bundle_gemfile) do
          execute :bundle, :exec, :rails, "db:migrate"
        end
      end
    end
  end

  desc "Precompile assets"
  task :assets_precompile do
    on roles(:web) do
      within backend_path do
        with rails_env: fetch(:rails_env), bundle_gemfile: fetch(:bundle_gemfile) do
          execute :bundle, :exec, :rails, "assets:precompile"
        end
      end
    end
  end

  desc "Restart Puma"
  task :restart_puma do
    on roles(:app) do
      execute :sudo, :systemctl, :restart, fetch(:backend_puma_service)
    end
  end

  desc "Restart Sidekiq"
  task :restart_sidekiq do
    on roles(:app) do
      execute :sudo, :systemctl, :restart, fetch(:backend_sidekiq_service)
    end
  end
end

before "deploy:check:linked_files", "backend:check_shared"

namespace :deploy do
  after :updated, "backend:bundle_install"
  after :updated, "backend:migrate"
  after :updated, "backend:assets_precompile"
  after :published, "backend:restart_puma"
  after :published, "backend:restart_sidekiq"
end