###### INSTRUCTIONS ########## 
### Requirements: This requires an LxAdmin VPS configured to use Apache and Passenger

### First Run ###
# 1. Setup your application under version control using either Git or Subversion
# 2. Install any gems your application needs on your VPS as the root user using the gem install command
# 3. On your local machine change to your application directory and run "capify ."
# 4. Place this deploy.rb in your /config directory
# 5. Edit all of the variables below
# 6. Run: "cap deploy:setup" , this will setup the capistrano directory structure
# 7. Run: "cap setup_domain" , this will add your domain and a database to LxAdmin.
#   This will also configure apache and setup a database.yml for you in your applications
#    /shared folder on the server
# 8. Run "cap deploy:cold", this will deploy your application on to the server and run your database migration.

### Deploy a new revision ###
# 1. Run "cap deploy"

##############################
# The following variables will need to be changed:

# The ip address of your VPS
set :ip_address, "69.25.136.239"

# Your repository type
set :scm, :git

# The name of your application, this will also be the folder were your application
# will be deployed to
set :application, "DepSamCms" 

# the url for your repository, This is displayed in the source repo control panel after clicking on your project
set :repository,  "git@github.com:evx001/DepSamCms.git"

# The domain(without the www) or subdomain you would like to deploy this application to
set :domain_name , "samantha-cook.com"

# Your desired database name, you will be prompted to enter in your desired password.
set :database_name , "samDB" # !NOTE! this is limited to 9 characters

###### There is no need to edit anything below this line ######
################ leave asis ####################
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