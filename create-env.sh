#!/usr/bin/bash

oc cluster up
#Create openshift env
oc login -u system:admin --insecure-skip-tls-verify=true
oc create sa robot -n myproject
oc describe sa robot -n myproject
token="$(oc describe sa robot)"
echo "step 1: '$token'"
token=$(echo "$token" | grep -A 2 "Mountable secrets" | grep -v "Tokens: ")
echo "step 2: $token"
token=$(echo "$token" | grep "robot-token-*")
echo "step 3: $token"
token=$(echo "$token" | cut --delimiter=: --fields=2)
echo "step 4: $token"
token=$(echo "$token" | tr -d '[:space:]')
echo "final token: $token"


oc adm policy add-role-to-user edit system:serviceaccount:myproject:robot -n myproject
oc describe secret $token -n myproject
token_val=$(oc describe secret $token | grep "token: *" )
token_val=$(echo "$token_val" | cut -c 7- | sed -e 's/^[ \t]*//')
echo "Token_val: $token_val"


#set up shared dir and scc restricted 
sudo mkdir /tmp/share
sudo chcon -R -t svirt_sandbox_file_t /tmp/share/
oc patch scc restricted -p 'allowHostDirVolumePlugin: true'
oc patch scc restricted -p '"runAsUser": {"type": "RunAsAny"}'

rm -f ~/.kube/config
oc login --token=$token_val --server=172.30.0.1:443 --insecure-skip-tls-verify=true
oc project myproject
oc create secret generic kubecfg --from-file=$HOME/.kube/config -n myproject
rm -f ~/.kube/config
oc login --username='developer' --password='developer' --server=localhost:8443 --insecure-skip-tls-verify=true
git clone https://github.com/FNNDSC/pman.git
git clone https://github.com/FNNDSC/pfioh.git
oc new-app pman/openshift/pman-openshift-template-without-swift.json
oc set env dc/pman OPENSHIFTMGR_PROJECT=myproject
oc new-app pfioh/openshift/pfioh-openshift-template-without-swift.json

#install virtual box
wget http://download.virtualbox.org/virtualbox/5.2.4/VirtualBox-5.2-5.2.4_119785_fedora26-1.x86_64.rpm
rpm -i VirtualBox-5.2-5.2.4_119785_fedora26-1.x86_64.rpm
sudo dnf install kernel-devel kernel-devel-4.14.11-300.fc27.x86_64
sudo dnf install elfutils-libelf-devel
sudo '/sbin/vboxconfig'

#install vagrant
wget https://releases.hashicorp.com/vagrant/2.0.1/vagrant_2.0.1_x86_64.rpm?_ga=2.103951622.700779187.1515609313-38000827.1515609313
mv 'vagrant_2.0.1_x86_64.rpm?_ga=2.103951622.700779187.1515609313-38000827.1515609313' vagrant_2.0.1_x86_64.rpm
rpm -i vagrant_2.0.1_x86_64.rpm

#install vagrant guest package manager
vagrant plugin install vagrant-vbguest

#start the box up
vagrant up
vagrant ssh -c "sudo bash startChris.sh"


#get default gateway for your localhost
HOST_IP=$(netstat -rn | grep "^0.0.0.0 " | cut -d " " -f10)

#modify openshift local to accomodae default gateway  ---> Rudolph may make changes to this
pfurl --verb POST --raw --http 192.168.50.4:5005/api/v1/cmd --httpResponseBodyParse --jsonwrapper 'payload' --msg \
"'openshiftlocal': {
            'data': {
                'addr':         '$HOST_IP:5055',
                'baseURLpath':  'api/v1/cmd/',
                'status':       'undefined',

                'storeAccess.tokenSet':  {
                    "action":   "internalctl",
                    "meta": {
                           "var":          "key",
                           "set":          "setKeyValueHere"
                       }
                },

                'storeAccess.addrGet':  {
                    "action":   "internalctl",
                    "meta": {
                        "var":          "storeAddress",
                        "compute":      "address"
                    }
                }

            },
            'compute': {
                'addr':         '$HOST_IP:5010',
                'baseURLpath':  'api/v1/cmd/',
                'status':       'undefined'
            }
        },"


