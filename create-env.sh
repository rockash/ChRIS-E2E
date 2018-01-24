#!/usr/bin/bash

debug=0
while getopts "dh" opt; do
    case ${opt} in
        d )
            echo "Debugging mode activated"
            debug=1 ;;
        h )
            echo "Passing the -d argument will put this script in debug mode. This add breakpoints to the script that require manual input to unblock, 
as well as many print statements. Always run this script with sudo permissions." 
            exit 0;;
        * )
            echo "Caught invalid args. Use the -h option to get help.
Exiting"
            exit 1 ;;
    esac
done

#install openshift client tools
if [ "$debug" == "1" ]; then
    printf "\n\nInstall docker from client tools\n\n"
fi
sudo dnf install docker

if [ "$debug" == "1" ]; then
    printf "\n\nconfiguring firewall for openshift\n\n"
fi
su -c "echo "\""'INSECURE_REGISTRY='--insecure-registry 172.30.0.0/16"\"" >> /etc/sysconfig/docker"
sudo systemctl daemon-reload
sudo systemctl restart docker

firewall-cmd --permanent --new-zone dockerc
firewall-cmd --permanent --zone dockerc --add-source 172.17.0.0/16
firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
firewall-cmd --permanent --zone dockerc --add-port 53/udp
firewall-cmd --permanent --zone dockerc --add-port 8053/udp
firewall-cmd --reload

if [ "$debug" == "1" ]; then
    printf "\n\nInstalling openshift origin...\n\n"
fi
wget https://github.com/openshift/origin/releases/download/v3.7.1/openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz
tar -xvf openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz 
sudo cp sudo cp openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit/oc /usr/bin
rm openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz


if [ "$debug" == "1" ]; then
    printf "The next phase installs and attempts to run Chris. Do you want to continue? [y|n]: "
    read -n 1 cont
    case "$cont" in
        y|Y)
            echo "Running Chris App..." ;;
        n|N)
            echo "Exiting!"
            exit 1 ;;
        *)
            echo "Invalid input! Exiting!"
            exit 1 ;;
    esac
fi


#get pfioh and pman
printf "\n\nCloning pman and pfioh\n\n"
git clone https://github.com/FNNDSC/pman.git
git clone https://github.com/FNNDSC/pfioh.git

sudo oc cluster up

if [ "$debug" == "1" ]; then
    printf "creating chris instance in openshift"
fi

#Create openshift env
sudo oc login -u system:admin --insecure-skip-tls-verify=true
sudo oc create sa robot -n myproject
sudo oc describe sa robot -n myproject


token="$(oc describe sa robot)"
if [ "$debug" == "1" ]; then
    echo "step 1: '$token'"
fi

token=$(echo "$token" | grep -A 2 "Mountable secrets" | grep -v "Tokens: ")
if [ "$debug" == "1" ]; then
    echo "step 2: $token"
fi

token=$(echo "$token" | grep "robot-token-*")
if [ "$debug" == "1" ]; then
    echo "step 3: $token"
fi

token=$(echo "$token" | cut --delimiter=: --fields=2)
if [ "$debug" == "1" ]; then
    echo "step 4: $token"
fi

token=$(echo "$token" | tr -d '[:space:]')
if [ "$debug" == "1" ]; then
    echo "final token: $token"
fi

sudo oc adm policy add-role-to-user edit system:serviceaccount:myproject:robot -n myproject
sudo oc describe secret $token -n myproject
token_val=$(oc describe secret $token | grep "token: *" )
token_val=$(echo "$token_val" | cut -c 7- | sed -e 's/^[ \t]*//')

if [ "$debug" == "1" ]; then
    echo "Token_val: $token_val"
fi


#set up shared dir and scc restricted 
sudo mkdir /tmp/share
sudo chcon -R -t svirt_sandbox_file_t /tmp/share/
sudo oc patch scc restricted -p 'allowHostDirVolumePlugin: true'
sudo oc patch scc restricted -p '"runAsUser": {"type": "RunAsAny"}'

rm -f ~/.kube/config
oc login --token=$token_val --server=172.30.0.1:443 --insecure-skip-tls-verify=true
oc project myproject
oc create secret generic kubecfg --from-file=$HOME/.kube/config -n myproject
rm -f ~/.kube/config
oc login --username='developer' --password='developer' --server=localhost:8443 --insecure-skip-tls-verify=true
oc new-app pman/openshift/pman-openshift-template-without-swift.json
oc set env dc/pman OPENSHIFTMGR_PROJECT=myproject
oc new-app pfioh/openshift/pfioh-openshift-template-without-swift.json

#install virtual box
if [ "$debug" == "1" ]; then
    printf "\n\nInstalling virtual box\n\n"
fi
wget http://download.virtualbox.org/virtualbox/5.2.4/VirtualBox-5.2-5.2.4_119785_fedora26-1.x86_64.rpm
rpm -i VirtualBox-5.2-5.2.4_119785_fedora26-1.x86_64.rpm
sudo dnf install kernel-devel kernel-devel-4.14.11-300.fc27.x86_64
sudo dnf install elfutils-libelf-devel
sudo '/sbin/vboxconfig'

#install vagrant

if [ "$debug" == "1" ]; then
    printf "\n\nInstalling Vagrant\n\n"
fi
sudo dnf install vagrant -y

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


