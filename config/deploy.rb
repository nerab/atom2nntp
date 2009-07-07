set :application, "atom2nntp"
set :deploy_to, "/var/www/#{application}"

default_run_options[:pty] = true
set :use_sudo, true

set :user, "suhlig"
role :app, "qa.uhcons.net"
role :web, "qa.uhcons.net"
role :db,  "qa.uhcons.net", :primary => true

set :scm, "git"
set :repository,  "."
set :deploy_via, :copy

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

