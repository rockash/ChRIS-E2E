# ChRIS End To End Testing Environment
This script autmatically builds and deploys the ChRIS backend in docker-compose and pman and pfioh in Open Shift. This has only been tested to work on
the latest fedora (f27 at the time of writing)

## Setup and Dependancies
-fill out in git-

## Options
Flag | Description
----------------- | -----------------
--deps | This will trigger the script to install and configure the necessary dependancies on your system **This will configure your firewall settings, change your seLinux to permissive, clone git repos, and install software on your system.** If you dont want to do this, or would rather do it yourself, follow the readme
--interactive [arg1 arg2 ...] | The specified services be restarted in interactive mode in a new shell window. This is mainly for debugging. Accepted arguments: pman, pfcon, pfioh, chris_dev all(equivilent to: pman pfcon pfioh chris_dev)
--test | This will run tests agains the components of the system to make sure they are working correctly 
--help | Prints this message and exits the script with code 0

## Usage

```shell
./mkenv.sh [options]
```
