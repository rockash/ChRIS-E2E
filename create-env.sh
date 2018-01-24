
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

skip=0
if [ "$debug" == "1" ]; then
    printf "This phase Installs Openshift and its dependancies. Do you want to Continue, Skip, or Exit? [c|s|e]: "
    read -n 1 checkpoint1
    echo ""
    case "$checkpoint1" in
        c|C)
            echo "Installing Openshift and its dependancies..." ;;
	s|S)
	    echo "Skipping!"
	    skip=1 ;;
        e|E)
            echo "Exiting!"
            exit 0 ;;
        *)
            echo "Invalid input! Exiting!"
            exit 1 ;;
    esac
fi

if [[ "$debug" == "0" || "$skip" == 0 ]]; then
    #install openshift client tools
    sudo dnf install docker -y

    printf "\n\nconfiguring firewall for openshift\n\n"
    su -c "echo INSECURE_REGISTRY=\'--insecure-registry 172.30.0.0/16\' >> /etc/sysconfig/docker"
    sudo systemctl daemon-reload
    sudo systemctl restart docker

    firewall-cmd --permanent --new-zone dockerc
    firewall-cmd --permanent --zone dockerc --add-source 172.17.0.0/16
    firewall-cmd --permanent --zone dockerc --add-port 8443/tcp
    firewall-cmd --permanent --zone dockerc --add-port 53/udp
    firewall-cmd --permanent --zone dockerc --add-port 8053/udp
    firewall-cmd --reload

    printf "\n\nInstalling openshift origin...\n\n"
    oc=$(ls /usr/bin | grep -w "oc")
    if [[ -z "$oc" || "$oc" != "oc" ]]; then
        wget https://github.com/openshift/origin/releases/download/v3.7.1/openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz
        tar -xvf openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz 
        sudo mv openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit/oc /usr/bin
        rm openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz
	sudo rm -rf openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit
    fi
fi

skip2=0
if [ "$debug" == "1" ]; then
    printf "The next phase will run Chris in openshift. Do you want to Continue, Skip, or Exit? [c|s|e]: "
    read -n 1 checkpoint2
    echo ""
    case "$checkpoint2" in
        c|C)
            echo "Installing Openshift and its dependancies..." ;;
	s|S)
	    echo "Skipping!"
	    skip2=1 ;;
        e|E)
            echo "Exiting!"
            exit 0 ;;
        *)
            echo "Invalid input! Exiting!"
            exit 1 ;;
    esac
fi

if [[ "$debug" == "0" || "$skip2" == 0 ]]; then
    #get pfioh and pman
    printf "\n\nCloning pman and pfioh\n\n"
    git clone https://github.com/FNNDSC/pman.git
    git clone https://github.com/FNNDSC/pfioh.git

    sudo oc cluster up
    printf "Creating ChRIS instance in openshift"

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
fi


skip3=0
if [ "$debug" == "1" ]; then
    printf "This final phase will create a virtual environment with the ChRIS backend running in it. Do you want to Continue, Skip, or Exit? [c|s|e]: "
    read -n 1 checkpoint3
    echo ""
    case "$checkpoint3" in
        c|C)
            echo "Installing Openshift and its dependancies..." ;;
	s|S)
	    echo "Skipping!"
	    skip3=1 ;;
        e|E)
            echo "Exiting!"
            exit 0 ;;
        *)
            echo "Invalid input! Exiting!"
            exit 1 ;;
    esac
fi

if [[ "$debug" == "0" || "$skip3" == 0 ]]; then
    #install virtual box
#    printf "\n\nInstalling virtual box\n\n"
#    cd /etc/yum.repos.d/
#    sudo wget http://download.virtualbox.org/virtualbox/rpm/fedora/virtualbox.repo
#    cd
#    cd ChRIS-E2E
#    sudo dnf update -y
#    sudo dnf install binutils gcc make patch libgomp glibc-headers glibc-devel kernel-headers kernel-devel dkms -y
#    sudo dnf install VirtualBox-5.2 -y
#    sudo /usr/lib/virtualbox/vboxdrv.sh setup
#    sudo usermod -a -G vboxusers $(whoami)
#    VirtualBox

    #install vagrant
    printf "\n\nInstalling Vagrant\n\n"
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

fi
