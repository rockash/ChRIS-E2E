#install and configure docker
sudo dnf install docker -y

#install docker compose
sudo dnf install docker-compose -y

#configure environment for openshift and chris
su -c "echo INSECURE_REGISTRY=\'--insecure-registry 172.30.0.0/16\' >> /etc/sysconfig/docker"
sudo systemctl daemon-reload
sudo systemctl restart docker
firewall-cmd --permanent --new-zone dockerc
firewall-cmd --permanent --zone dockerc --add-source 172.17.0.0/16
firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
firewall-cmd --permanent --zone dockerc --add-port 53/udp
firewall-cmd --permanent --zone dockerc --add-port 8053/udp
firewall-cmd --reload
sudo setenforce 0

#install openshift client tools
wget https://github.com/openshift/origin/releases/download/v3.7.1/openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz
tar -xvf openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz 
sudo mv openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit/oc /usr/bin
rm openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz
sudo rm -rf openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit