#
# Cookbook Name:: mediawiki
# Recipe:: default
#
# Copyright 2011, ccat
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
include_recipe "php"
include_recipe "apache2::mod_php5"

# CentOS7 default yum repository doesn't have mysql.
# @TODO: If CentOS7, install mariadb.
if platform?(:centos) && node[:platform_version].to_i < 7 then
 include_recipe "mysql::client"
end

%w(php-mysql php-xml).each do |pkg|
 package pkg
end

node.set_unless[:mediawiki][:installdbPass] = node[:mysql][:server_root_password]

node.set_unless[:mediawiki][:wgDBpassword] = secure_password
node.set_unless[:mediawiki][:dbAdminPass] = secure_password
node.set_unless[:mediawiki][:wgSecretKey] = secure_password
node.set_unless[:mediawiki][:wgUpgradeKey] = secure_password

template "/tmp/set_pass.sql" do
 source "set_pass.sql.erb"
 owner "root"
 group "root"
 mode "0640"
 not_if do File.exists?(node[:mediawiki][:directory]) end
end

remote_file "/tmp/mediawiki-1.17.0.tar.gz" do
 source "http://download.wikimedia.org/mediawiki/1.17/mediawiki-1.17.0.tar.gz"
 owner "root"
 group "root"
 mode "0640"
 not_if do File.exists?(node[:mediawiki][:directory]) end
end


script "set_mediawiki" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  not_if do File.exists?(node[:mediawiki][:directory]) end
  code <<-EOH
  tar -zxf mediawiki-1.17.0.tar.gz
  mv mediawiki-1.17.0 #{node[:mediawiki][:directory]}
  chown -R #{node[:apache][:user]}:#{node[:apache][:group]} #{node[:mediawiki][:directory]}
  cd #{node[:mediawiki][:directory]}
  php maintenance/install.php --dbname #{node[:mediawiki][:wgDBname]} --dbpass #{node[:mediawiki][:wgDBpassword]}  --dbserver #{node[:mediawiki][:wgDBserver]} --dbuser #{node[:mediawiki][:wgDBuser]} --installdbpass #{node[:mediawiki][:installdbPass]}  --pass #{node[:mediawiki][:dbAdminPass]} --installdbuser root --lang #{node[:mediawiki][:wgLanguageCode]}  #{node[:mediawiki][:wgSitename]} #{node[:mediawiki][:dbAdminUser]}
  mv LocalSettings.php LocalSettings_autogenerate.php
  EOH
end

userName=node[:apache][:user]
groupName=node[:apache][:group]

template node[:mediawiki][:directory]+"/LocalSettings.php" do
 source "LocalSettings.php.erb"
 owner userName
 group groupName
 mode "0640"
end

directory node[:mediawiki][:directory]+"/config" do
  owner userName
  group groupName
  mode "0755"
  only_if {node[:mediawiki][:access2config_folder]=="true"}
end

directory node[:mediawiki][:directory]+"/mw-config" do
  owner userName
  group groupName
  mode "0755"
  only_if {node[:mediawiki][:access2config_folder]=="true"}
end

directory node[:mediawiki][:directory]+"/config" do
  owner userName
  group groupName
  mode "0400"
  only_if {node[:mediawiki][:access2config_folder]=="false"}
end

directory node[:mediawiki][:directory]+"/mw-config" do
  owner userName
  group groupName
  mode "0400"
  only_if {node[:mediawiki][:access2config_folder]=="false"}
end

web_app 'mediawiki' do
  template 'mediawiki.conf.erb'
end
