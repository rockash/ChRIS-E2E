# ChRIS End To End Testing Environment
This script autmatically builds and deploys the ChRIS backend in docker-compose and pman and pfioh in Openshift. Currently,
this only works locally. I am working on an implementation of this that builds the end to end system in a vagrant vm as well. Note that if you include the --deps flag, this script will install software to your local filesystem, install dnf updates, foward ports in your firewall, and set your SELinux to permissive. If this is not desirable to you, you may want to manually install the dependancies.

## Options
Flag | Description
----------------- | -----------------
--deps | This will trigger the script to install and configure the necessary dependancies on your system
--interactive | The ChRIS_backend container will be run in interactive mode at the end of this script. **Note: if you include this flag, when the script ends the terminal buffer you are using will be attached to the shell of the ChRIS_backend container and you will no longer be able to use it**
--vagrant | The end to end system will be deployed in a vagrant vm instead of on your local system. **WARNING: this has not yet been implemented succesfully**
--test | This will run tests agains the components of the system to make sure they are working correctly **NOT WORKINGxz**
--help | Prints this message and exits the script with code 0

## Usage
You must run this bash script with sudo permissions. The easiest way to do this is as follows:

```shell
sudo bash mkenv.sh [options]
```
