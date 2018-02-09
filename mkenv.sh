#!/bin/bash

INTERACTIVE=0
DEPS=0
TEST=0
args=()
PMAN_PATH=""

until [ -z "$1" ]
do
    case "$1" in
        --deps)
            DEPS=1
            ;;
        --interactive)
            INTERACTIVE=1
            until [[ -z "$2" || "$2" == "--"* ]];do
                args+=("$2")
                shift
            done
            ;;
        --test)
            TEST=1
            ;;
        --help)
            echo """
Usage: ./mkenv.sh [options]
Options:
    --deps                              This will trigger the script to install and configure the
                                            necessary dependancies on your system
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
                                                all                  (equivilent to: pfcon pman pfioh)

    --test                              This will run tests agains the components of the system to 
                                            make sure they are working correctly, then it will exit
                                            with code 0

    --help                              Prints this message and exits the script with code 0
"""
            exit 0
            ;;
    esac
    shift
done

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
    pfurl --verb POST --raw --http 127.0.0.1:5055/api/v1/cmd --httpResponseBodyParse --jsonwrapper 'payload' --msg \
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
    #check pfcon
    echo "Testing if local pman and pfioh can be reached with hello"
    pfurl --verb POST --raw --http 127.0.0.1:5005/api/v1/cmd --httpResponseBodyParse --jsonwrapper 'payload' --msg \
    '{  "action": "hello",
        "meta": {
                    "askAbout":     "sysinfo",
                    "echoBack":      "Hi there!",
                    "service":       "host"
                }
    }'
    echo "Testing if local pman and pfioh can be reached with hello"
    pfurl --verb POST --raw --http 127.0.0.1:5005/api/v1/cmd --httpResponseBodyParse --jsonwrapper 'payload' --msg \
    '{  "action": "hello",
        "meta": {
                    "askAbout":     "sysinfo",
                    "echoBack":      "Hi there!",
                    "service":       "openshiftlocal"
                }
    }'
    
    #full integration tests
    echo "Running Integration tests"
    pushd ChRIS_ultron_backEnd/
    sudo docker-compose exec chris_dev python manage.py test
    exit 0
fi

# if the user wants to install dependancies on their local
if [ "$DEPS" -eq "1" ];then
    #these will throw errors if they are alreay in local dir, but the code will keep running
    git clone https://github.com/FNNDSC/pman.git
    git clone https://github.com/FNNDSC/pfioh.git
    git clone https://github.com/FNNDSC/ChRIS_ultron_backEnd.git
    git clone https://github.com/FNNDSC/pfurl.git

    #install gcc (needed for pfurl and pip)
    sudo dnf install gcc

    #install pfurl
    pushd pfurl/
    sudo pip3 install .
    popd   

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
    sudo dnf install origin-clients.x86_64

    #update packages  :( slow but it wont work if you dont.
    sudo dnf update -y
fi

#local install of chris env
echo "Setting up local Chris Cluster"
pushd ChRIS_ultron_backEnd/
sudo docker-compose up -d
sudo docker-compose exec chris_dev_db sh -c 'while ! mysqladmin -uroot -prootp status 2> /dev/null; do sleep 5; done;'
sudo docker-compose exec chris_dev_db mysql -uroot -prootp -e 'GRANT ALL PRIVILEGES ON *.* TO "chris"@"%"'
sudo docker-compose exec chris_dev /bin/bash -c 'python manage.py migrate'
echo "Setting superuser chris:chris1234 ..."
sudo docker-compose exec chris_dev /bin/bash -c 'python manage.py createsuperuser --noinput --username chris --email dev@babymri.org 2> /dev/null;'
sudo docker-compose exec chris_dev /bin/bash -c \
'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"chris\"); user.set_password(\"chris1234\"); user.save()"'
echo ""
echo "Setting normal user cube:cube1234 ..."
sudo docker-compose exec chris_dev /bin/bash -c 'python manage.py createsuperuser --noinput --username cube --email dev@babymri.org 2> /dev/null;'
sudo docker-compose exec chris_dev /bin/bash -c \
'python manage.py shell -c "from django.contrib.auth.models import User; user = User.objects.get(username=\"cube\"); user.set_password(\"cube1234\"); user.save()"'
echo ""
echo "Setting up openshift environment"
popd
sudo oc cluster up
sudo oc login -u system:admin --insecure-skip-tls-verify=true
sudo oc create sa robot -n myproject
sudo oc describe sa robot -n myproject
token="$(sudo oc describe sa robot)"
token=$(echo "$token" | grep -A 2 "Mountable secrets" | grep -v "Tokens: ")
token=$(echo "$token" | grep "robot-token-*")
token=$(echo "$token" | cut --delimiter=: --fields=2)
token=$(echo "$token" | tr -d '[:space:]')
sudo oc adm policy add-role-to-user edit system:serviceaccount:myproject:robot -n myproject
sudo oc describe secret $token -n myproject
token_val=$(sudo oc describe secret $token | grep "token: *" )
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

#restarts jobs in interactive terminals
if [ "$INTERACTIVE" -eq "1" ];then
    if [ ${#args[@]} -eq 0 ];then
        echo "You did not provide any services to run interactively. For help run the script with --help"
        exit 1
    elif [[ ${#args[@]} -eq 1 && "${args[0]}" == "all" ]];then
        args=(pfcon pman pfioh)
        pushd ChRIS_ultron_backEnd
        for restart in "${args[@]}"; do
            sudo docker-compose stop "$restart"_service && docker-compose rm -f "$restart"_service
            gnome-terminal -e docker-compose run --service-ports "$restart"_service
    else
        pushd ChRIS_ultron_backEnd
        for restart in "${args[@]}"; do
            sudo docker-compose stop "$restart"_service && docker-compose rm -f "$restart"_service
            gnome-terminal -e docker-compose run --service-ports "$restart"_service        
fi
exit 0