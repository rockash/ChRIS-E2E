# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'virtualbox'
Vagrant.configure("2") do |config|
  config.vm.box = "generic/fedora27"
  config.vm.network "public_network", ip: "192.168.0.17"
  config.vm.provision "shell", path: "provision.sh"
  config.vm.provision "file", source: "mkenv.sh", destination: "mkenv.sh"
  config.vm.provision "file", source: "createUsers.py", destination: "createUsers.py"
end