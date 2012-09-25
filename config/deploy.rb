set :user , "root"
set :domain_password, Proc.new {CLI.password_prompt "desired domain password: "}
set :database_password, Proc.new {CLI.password_prompt "desired database password: "}
set :deploy_to, "/home/admin/#{application}"
set :shared_directory, "#{deploy_to}/shared"
set :use_sudo, false
set :group_writable, false
default_run_options[:pty] = true

role :app, ip_address
role :web, ip_address
role :db,  ip_address, :primary => true

task :after_update_code, :roles => [:web, :db, :app] do
  run "chmod 755 #{release_path}/public"
  run "chown admin:admin #{release_path} -R"
  begin
    run "rm -f #{release_path}/config/database.yml"
  rescue Exception => error
  end
  run "ln -s #{shared_directory}/database.yml #{release_path}/config/database.yml"
end

namespace :deploy do
  desc "restart passenger"
  task :restart do
    passenger::restart
  end
  [:start, :stop].each do |t|
    desc "#{t} task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end

end

namespace :passenger do
  desc "Restart passenger"
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end
end

task :setup_domain, :hosts => ip_address do
  begin
     run "/script/add --name=rpdefault --v-webipaddress=#{ip_address}  --v-mmailipaddress=#{ip_address} --class=dnstemplate --v-nameserver_f=ns1.vpsplayground.net --v-secnameserver_f=ns2.vpsplayground.net"
  rescue Exception => error
    puts "dns zone already added."
  end
  run "/script/add --class=domain --name=#{domain_name} --v-docroot=#{application}/current/public --v-password=#{domain_password} --v-dnstemplate_name=rpdefault.dnst"
  run "/script/add --class=mysqldb --name=#{database_name} --v-dbpassword=#{database_password}"
  database_config = "production:\n  adapter: mysql\n  encoding: utf8\n  database: #{database_name}\n  username: #{database_name}\n  password: #{database_password}"
  puts database_config
  put database_config, "#{shared_directory}/database.yml"
  run "rm -rf /home/admin/#{application}/current"
  puts "\n\nYou will now login to hypervm at https://vps.webhostserver.biz:8887, click on DNS and add zone record for #{domain_name}, then set your nameservers for your domain at your domain registrar to ns1.vpsplayground.net and ns2.vpsplayground.net\n\n"

end