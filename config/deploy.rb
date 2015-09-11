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

set :linked_files, fetch(:linked_files, []).push('config/database.yml', 'config/secrets.yml')
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle')

set :keep_releases, 5

set :puma_conf, "#{shared_path}/puma.rb"
set :puma_state, "#{shared_path}/tmp/pids/puma.state"
set :puma_role, :web
set :puma_workers, 2
set :puma_preload_app, false
set :puma_threads, [0, 4]

set :rvm_type, :user
set :rvm_ruby_version, '2.2.2@retailer-products'
set :rvm_roles, %w{app web}

set :bundle_binstubs, nil

after 'deploy:restart', 'puma:restart'

# namespace :deploy do
#
#   after :restart, :clear_cache do
#     on roles(:web), in: :groups, limit: 3, wait: 10 do
#       # Here we can do anything such as:
#       # within release_path do
#       #   execute :rake, 'cache:clear'
#       # end
#     end
#   end
#
# end
