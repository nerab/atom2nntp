set :application, "atom2nntp"
set :deploy_to, "/var/www/#{application}"

default_run_options[:pty] = true
set :use_sudo, true

set :user, "suhlig"
role :app, "qa.uhcons.net"
role :web, "qa.uhcons.net"
role :db,  "qa.uhcons.net", :primary => true

set :scm, "git"
set :repository,  "git://github.com/nerab/atom2nntp.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :git_enable_submodules, 1
# set :deploy_via, :copy

namespace :passenger do
  desc <<-DESC
  Restart the application altering tmp/restart.txt for passenger.
  DESC
  task :restart, :roles => :app do
    run "touch  #{release_path}/tmp/restart.txt"
  end
end

namespace :deploy do
  %w(start restart).each { |name| task name, :roles => :app do passenger.restart end }
end

after :deploy, "passenger:restart"

desc "Stop the backgroundrb server"
task :stop_backgroundrb , :roles => :app do
  run "cd #{current_path} && ./script/backgroundrb stop"
end

desc "Start the backgroundrb server" 
task :start_backgroundrb , :roles => :app do
  run "cd #{current_path} && nohup ./script/backgroundrb start -e production > #{current_path}/log/backgroundrb-cap.log 2>&1" 
end

desc "Restart the backgroundrb server"
task :restart_backgroundrb, :roles => :app do
  stop_backgroundrb
  start_backgroundrb
end
