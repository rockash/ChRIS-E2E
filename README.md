# ChRIS End To End Testing Environment
This script automatically builds and deploys the ChRIS backend in docker-compose and pman and pfioh in OpenShift. This has only been tested to work on
the latest fedora (f27 at the time of writing)

## Setup and Dependencies
### Docker
You must have a specific version of docker on your system for OpenShift to work. Currently, using the version in the dnf library is the easiest way to guarantee that you have the right version. Docker Compose is also required for building the FNNDSC ChRIS Backend. It is convenient to install them both together like this:
```shell
sudo dnf install docker docker-compose -y
```

### OpenShift
For OpenShift to run on your desktop environment, an insecure registry has to be added to your docker sysconfig, and changes need to be made to your firewall. If you want more information on running OpenShift, refer to [this page.](https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md) The following commands will properly configure your environment and install OpenShift:
```shell
dnet=$(sudo docker network inspect -f "{{range .IPAM.Config }}{{ .Subnet }}{{end}}" bridge)
su -c "echo INSECURE_REGISTRY=\'--insecure-registry 172.30.0.0/16\' >> /etc/sysconfig/docker"
sudo systemctl daemon-reload
sudo systemctl restart docker
firewall-cmd --permanent --new-zone dockerc
firewall-cmd --permanent --zone dockerc --add-source $dnet
firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
firewall-cmd --permanent --zone dockerc --add-port 53/udp
firewall-cmd --permanent --zone dockerc --add-port 8053/udp
firewall-cmd --reload
sudo dnf install origin-clients.x86_64
sudo dnf update -y
```

### ChRIS Backend
To communicate with the components of ChRIS, you need a python function called pfurl. The easiest way to get it working is as follows:
```shell
git clone https://github.com/FNNDSC/pfurl.git
sudo dnf install gcc
pushd pfurl/
sudo pip3 install .
popd   
```

## Before you run
In order to run this script, a version of the ChRIS Ultron Backend, Pfioh, and Pman must be in your working directory. If you plan to make changes to these repos, you should fork them and clone your forks in ChRIS-E2E's working directory. If you don't have a fork of these repos, you can clone them from the following repos with these commands:
```shell
 git clone https://github.com/FNNDSC/pman.git
 git clone https://github.com/FNNDSC/pfioh.git
 git clone https://github.com/FNNDSC/ChRIS_ultron_backEnd.git
```

## Usage
```
./mkenv.sh [options]

Options:
    --deps                              This will trigger the script to install and configure the
                                            necessary dependencies on your system
                                            WARNING: this will configure your firewall settings, 
                                            change your seLinux to permissive, clone git repos,
                                            and install software on your system. If you dont want
                                            to do this, or would rather do it yourself, refer to
                                            the README

    --interactive [arg1 arg2 ...]       The specified services be restarted in interactive mode in
                                            a new shell window. This is mainly for debugging. If you
                                            want to change pfcon to interactive mode along with a
                                            different service, you must put pfcon first!
                                            Accepted arguments: 
                                                pfcon [pman pfioh]   (pman pfioh optional)
                                                pfioh pman           (one or both in any order)
                                                all                  (equivalent to: pfcon pman pfioh)

    --test                              This will run tests against the components of the system to 
                                            make sure they are working correctly, then it will exit
                                            with code 0

    --help                              Prints this message and exits the script with code 0
```
