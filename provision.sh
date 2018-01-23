#docker CE
sudo apt-get update
sudo apt-get install \
    linux-image-extra-$(uname -r) \
    Linux-image-extra-virtual
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

#docker compose
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
apt-key fingerprint 0EBFCD88
add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install docker-ce

#get docker engine
sudo apt-get install --no-install-recommends \
    apt-transport-https \
    curl \
    software-properties-common
sudo apt-get install -y --no-install-recommends \
    linux-image-extra-$(uname -r) \
    linux-image-extra-virtual
curl -fsSL 'https://sks-keyservers.net/pks/lookup?op=get&search=0xee6d536cf7dc86e2d7d56f59a178ac6c6238f52e' | apt-key add -
add-apt-repository \
   "deb https://packages.docker.com/1.13/apt/repo/ \
   ubuntu-$(lsb_release -cs) \
   main"
sudo apt-get update
sudo apt-get -y install docker-engine

#allows home user to access daemon
sudo usermod -a -G docker $USER

#get the latest docker compose
curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

#enable the daemon at startup
sudo systemctl enable docker 
sudo systemctl start docker

#clone the backend repo
sudo apt-get install git
git clone https://github.com/iamemilio/ChRIS_ultron_backEnd.git
git checkout LocalE2E

# chris dependancies (I dont think I need most of these)
sudo apt-get install -y python3-dev 
sudo apt-get install -y python3 python3-pip
sudo apt-get install -y python-pip libmysqlclient-dev
sudo apt-get install -y libssl-dev 
sudo apt-get install -y libcurl4-openssl-dev
sudo apt-get install -y apache2 apache2-dev
sudo pip install virtualenv virtualenvwrapper

sudo apt-get update
sudo pip3 install pfurl