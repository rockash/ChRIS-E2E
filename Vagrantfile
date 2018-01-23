# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network :forwarded_port, guest: 5055, host: 5055
  # config.vm.network :forwarded_port, guest: 5010, host: 5010
  # config.vm.newtork :forwarded_port, guest: 5005, host: 5005
  # config.vm.network :forwarded_port, guest: 8000, host: 8000

  #this isnt explicitly necessary, but is a good failsafe option for right now --> may delete in future iterations 
  config.vm.network "private_network", ip: "192.168.50.4"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  
  config.vm.provider "virtualbox" do |v|
    # Customize the amount of memory on the VM:
    v.memory = "2048"
    #cap cpu usage at 50%
    v.customize ["modifyvm", :id, "--cpuexecutioncap", "50"]
  end

  #provision the vm with docker tools
  config.vm.provision "shell", path: "provision.sh"

  #pass it a script to launch CUBE
  config.vm.provision "file", source: "startChris.sh", destination: "startChris.sh"
end