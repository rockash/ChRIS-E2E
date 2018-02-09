#!/bin/bash

INTERACTIVE=0
DEPS=0
TEST=0
VAGRANT=0

until [ -z "$1" ]
do
    case "$1" in
        --deps)
            DEPS=1
            ;;
        --interactive)
            INTERACTIVE=1
            ;;
        --vagrant)
            VAGRANT=1
            ;;
        --test)
            TEST=1
            ;;
        --help)
            echo """
This script autmatically builds and deploys the ChRIS backend in docker-compose and pman and pfioh in Openshift. Currently,
this only works locally. I am working on an implementation of this that builds the end to end system in a vagrant vm as well.

This script takes the following flags:
    --deps              This will trigger the script to install and configure the necessary dependancies on your system

    --interactive       The ChRIS_backend container will be run in interactive mode at the end of this script.
                            Note: if you include this flag, when the script ends the terminal buffer you are using
                            will be attached to the docker shell of the ChRIS_backend container
    
    --vagrant           The end to end system will be deployed in a vagrant vm instead of on your local system.
                            WARNING: this has not yet been implemented

    --test              This will run tests agains the components of the system to make sure they are working correctly and
                            can be reached  --!! Not working right now

    --help              Prints this message and exits the script with code 0
"""
            exit 0
            ;;
    esac
    shift
done

if [[ "$DEPS" -eq "1" && "$VAGRANT" -eq "0" ]];then
    #install gcc (needed for pfurl and pip)
    sudo dnf install gcc

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
    #cleanup of download files
    rm openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit.tar.gz
    sudo rm -rf openshift-origin-client-tools-v3.7.1-ab0f056-linux-64bit

    #update packages  :( slow but it wont work if you dont.
    sudo dnf update -y
fi

if [ "$VAGRANT" -eq "0" ];then
    #these will throw errors if they are alreay in local dir, but the code will keep running
    git clone https://github.com/FNNDSC/pman.git
    git clone https://github.com/FNNDSC/pfioh.git
    git clone https://github.com/FNNDSC/ChRIS_ultron_backEnd.git
    git clone https://github.com/FNNDSC/pfurl.git

    #install pfurl
    pushd pfurl/
    sudo pip3 install .
    popd

    #set up chris env
    echo "Setting up local Chris Cluster"
    pushd ChRIS_ultron_backEnd/
    sudo docker-compose up -d
    sudo docker-compose exec chris_dev_db sh -c 'while ! mysqladmin -uroot -prootp status 2> /dev/null; do sleep 5; done;'
    sudo docker-compose exec chris_dev_db mysql -uroot -prootp -e 'GRANT ALL PRIVILEGES ON *.* TO "chris"@"%"'
    sudo docker-compose exec chris_dev /bin/bash -c 'python manage.py migrate'

    echo "Setting superuser chris:chris1234 ..."
    docker-compose exec chris_dev /bin/bash -c 'python manage.py createsuperuser --noinput --username chris --email dev@babymri.org 2> /dev/null;'
    docker-compose exec chris_dev /bin/bash -c \
    'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"chris\"); user.set_password(\"chris1234\"); user.save()"'
    echo ""
    echo "Setting normal user cube:cube1234 ..."
    docker-compose exec chris_dev /bin/bash -c 'python manage.py createsuperuser --noinput --username cube --email dev@babymri.org 2> /dev/null;'
    docker-compose exec chris_dev /bin/bash -c \
    'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"cube\"); user.set_password(\"cube1234\"); user.save()"'
    echo ""

    #find and stop the docker-compose pman container
    pman=$(sudo docker ps | grep 'fnndsc/pman')
    if [ -z pman ]; then
        break
    else
        pman=($pman)
        sudo docker stop ${pman[0]}
    fi

    #find and stop the docker-compose pfioh container
    pfioh=$(sudo docker ps | grep 'fnndsc/pfioh')
    if [ -z pfioh ]; then
        break
    else
        pfioh=($pfioh)
        sudo docker stop ${pfioh[0]}
    fi
    
    echo "Setting up openshift environment"
    popd
    sudo oc cluster up
    sudo oc login -u system:admin --insecure-skip-tls-verify=true
    sudo oc create sa robot -n myproject
    sudo oc describe sa robot -n myproject
    token="$(oc describe sa robot)"
    token=$(echo "$token" | grep -A 2 "Mountable secrets" | grep -v "Tokens: ")
    token=$(echo "$token" | grep "robot-token-*")
    token=$(echo "$token" | cut --delimiter=: --fields=2)
    token=$(echo "$token" | tr -d '[:space:]')
    sudo oc adm policy add-role-to-user edit system:serviceaccount:myproject:robot -n myproject
    sudo oc describe secret $token -n myproject
    token_val=$(oc describe secret $token | grep "token: *" )
    token_val=$(echo "$token_val" | cut -c 7- | sed -e 's/^[ \t]*//')
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

    if [ "$TEST" -eq "1" ]; then
        #check pman
        echo "Testing if pman can be reached with hello"
        pfurl --verb POST --raw --http pman-myproject.127.0.0.1.nip.io/api/v1/cmd --jsonwrapper 'payload' --msg \
         '{  "action": "hello",
                 "meta": {
                         "askAbout":     "sysinfo",
                         "echoBack":     "Hi there!"
                 }
         }' --quiet --jsonpprintindent 4 
        
        #check pfioh
        echo "Testing if pfioh can be reached with hello"
        pfurl --verb POST --raw --http pfioh-myproject.127.0.0.1.nip.io/api/v1/cmd --httpResponseBodyParse --jsonwrapper 'payload' --msg \
         '{  "action": "hello",
                 "meta": {
                         "askAbout":     "sysinfo",
                         "echoBack":     "Hi there!"
                 }
         }' --quiet --jsonpprintindent 4 

        #check CUBE user chris
        echo "Testing if the backend can be reached by user chris"
        pfurl --auth chris:chris1234 --verb GET --raw --http 127.0.0.1:8000/api/v1/ \
            --quiet --jsonpprintindent 4

        #check CUBE user CUBE
        echo "Testing if the backend can be reached by user cube"
        pfurl --auth cube:cube1234 --verb GET --raw --http 127.0.0.1:8000/api/v1/ \
            --quiet --jsonpprintindent 4

        #check pfcon  !!!hangs
        echo "Testing if pfcon can be reached with hello"
        pfurl --verb POST --raw --http 127.0.0.1:5005/api/v1/cmd --httpResponseBodyParse --jsonwrapper 'payload' --msg \
        '{  "action": "hello",
            "meta": {
                        "askAbout":     "sysinfo",
                        "echoBack":      "Hi there!",
                        "service":       "host"
                    }
        }'

    fi

    if [ "$INTERACTIVE" -eq "1" ];then
        #run with interactive terminal locks u into tty
        pushd ChRIS_ultron_backEnd
        sudo docker-compose stop chris_dev
        sudo docker-compose rm -f chris_dev
        sudo docker-compose run --service-ports chris_dev
    fi
fi