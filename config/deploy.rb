# config valid only for current version of Capistrano
lock '3.4.0'

set :application, 'retailer-products'
set :repo_url, 'git@bitbucket.org:antonzaytsev/product_match.git'

set :deploy_to, '/home/app/retailer-products'

set :branch, 'master'
set :scm, :git
set :format, :pretty
set :pty, true

set :ssh_options, {
    forward_agent: true,
  }

set :log_level, :info #:debug

set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml', 'config/god.rb', 'config/sidekiq.yml', 'config/sidekiq_import.yml', '.env')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'tmp/sources', 'vendor/bundle', 'public/downloads')

set :keep_releases, 5

set :puma_conf, "#{shared_path}/puma.rb"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_role, :web
set :puma_workers, 2
set :puma_preload_app, false
set :puma_threads, [0, 4]

set :rvm_type, :user
set :rvm_ruby_version, '2.3.0@retailer-products'
set :rvm_roles, %w{app web}

set :bundle_binstubs, nil

after 'deploy:restart', 'puma:restart'

set :god_pid, "#{shared_path}/tmp/pids/god.pid"
set :god_config, "#{release_path}/config/god.rb"

namespace :god do
  def god_is_running
    capture(:bundle, "exec god status > /dev/null 2>&1 || echo 'god not running'") != 'god not running'
  end

  # Must be executed within SSHKit context
  def start_god
    execute :bundle, "exec god -c #{fetch :god_config}"
  end

  desc "Start god and his processes"
  task :start do
    on roles(:web) do
      within release_path do
        with RAILS_ENV: fetch(:rails_env) do
          start_god
        end
      end
    end
  end

  desc "Terminate god and his processes"
  task :stop do
    on roles(:web) do
      within release_path do
        if god_is_running
          execute :bundle, "exec god terminate"
        end
      end
    end
  end

  desc "Restart god's child processes"
  task :restart do
    on roles(:web) do
      within release_path do
        with RAILS_ENV: fetch(:rails_env) do
          if god_is_running
            execute :bundle, "exec god terminate"
          end
          start_god
        end
      end
    end
  end
end

after "deploy:updated", "god:restart"