#!/usr/bin/env bash
sudo systemctl start docker 
WORKON_HOME=~/Python_Envs
source /usr/local/bin/virtualenvwrapper.sh
mkvirtualenv --python=python3 chris_env
workon chris_env
cd ChRIS_ultron_backEnd/ 
git checkout LocalE2E
sudo bash docker-make-chris_dev.sh -p chris:chris1234 -p cube:chris1234