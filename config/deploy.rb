# config valid only for Capistrano 3.1
lock '3.10.1'

set :application, 'coinmarketcap.northpole.ro'
set :repo_url, 'https://github.com/mess110/coinmarketcap.northpole.ro.git'
set :format_options, log_file: 'logs/capistrano.log'

# Default branch is :master
# ask :branch, proc { `git rev-parse --abbrev-ref HEAD`.chomp }

# Default deploy_to directory is /var/www/my_app
set :deploy_to, '/home/kiki/coinmarketcap.northpole.ro'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
# set :log_level, :debug

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# set :linked_files, %w{config/database.yml}

# Default value for linked_dirs is []
set :linked_dirs, %w{public/api logs}
# append :linked_dirs, '.bundle'

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }
set :rvm_ruby_string, '2.4.3@coinmarketcap.2.4.3'

# Default value for keep_releases is 5
# set :keep_releases, 5

namespace :deploy do

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      execute 'source ~/.rvm/environments/ruby-2.4.3@coinmarketcap.2.4.3 && bundle'
      execute :touch, release_path.join('tmp/restart.txt')
      # TODO fix this hack
      execute "source ~/.rvm/environments/ruby-2.4.3@coinmarketcap.2.4.3 && cd #{release_path} && rake generate:doc"
    end
  end

  after :publishing, :restart

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

end
