## Introduction

To use docker solution to manage a customized lava lab, we do some extension based on lava official slave image.

### Docker solution advantage:

* Could use any physical linux variant to quick setup a lava slave. (The traditional non-container solution can just work on debian os, additionally just some version of debian)

* Could easily upgrade/downgrade lava slave to any version easily with just one command without feel pain of library conflict.

* As we persist lavacli identity, ser2net configure, and other lab scripts with bind mount, it means upgrade/re-setup lava slave will require nothing from user side to reconfigure.

* For android, even job failure, we can still keep a spot to debug as docker will not leave but lxc will be stop by lava.

### Detail solutions:

Currently, it just supports android & linux, we separate the solutions just because the way to configure containers may varies from a variety of situations to situations.

#### a) Solution for android:

* _Main extension:_

    For android, as lxc cannot run inside docker, so lxc-mocker is used in official slave image to simulate lxc. As a result, lxc no longer play the role to separate the environment for different devices, so we have to use multiple docker containers to simulate the case.

    That means, for every single docker container, just one device could be linked into one container. **Don't** try to link more than one device to per container, it will make actions(e.g. apt) which in the past separated by lxc conflict with each other if multiple jobs were triggered.

    At last, an enhanced `lava_lxc_device_add.py` had to be added to image to make device dynamic been seen in different docker container, otherwise adb in one container may grab all android devices for other containers.

* _Limit:_

  * Can no longer specify android host operation's environment, adb operation will be run in docker debian container.

  * Cannot use host's adb daemon together with this solution.

  * Cannot add more than one device to one container, that means in one physical machine, we need multiple containers together to support multiple devices.

    Sample architecture like follows:

        Physical Machine -> LAVA Container 1 -> Android device 1
                         -> LAVA Container 2 -> Android device 2
                         -> ...              -> ...
                         -> LAVA Container N -> Android device N

#### b) Solution for linux:

* _Main extension:_

    For linux, we mainly enable tftp & nfs in container, this makes the linux docker image out of box for use.

* _Limit:_

    This solution share the network namespace of host, this is because if we use the default docker0 bridge, the container's ip will be an internal ip which cannot not be connected by device when DUT do tftp & nfs operation. So, we choose to share host's network namespace.

    As a result, **only** one linux container could be active at the same time on physical machine. Meanwhile, the `slave control script` will automatically close host's tftp & nfs for you when start linux container.

    Sample architecture like follows:

        Physical Machine -> LAVA Container -> Linux device 1
                                           -> Linux device 2
                                           -> ...
                                           -> Linux device N

## Prerequisites

>     OS: Linux distribution, 64 bits, recommendation >= ubuntu14.04, centos7.3
>     Kernel Version >= 3.10
>     Docker: Enabled
>     SSH: Enabled

**NOTE**: You can use `curl https://get.docker.com/ | sudo sh` to install docker or visit [docker official website](https://docs.docker.com/install/linux/docker-ce/ubuntu/) to get the latest guide.

## Slave Control Script

The slave script (`lava_docker_slave.sh`) could be executed with root permission or use `sudo usermod -aG docker $USER` to grants privileges to current user. You can use `./lava_docker_slave.sh` to get the usage of this install script, similar to next:

    NAME
        lava_docker_slave.sh - lava docker slave install script
    SYNOPSIS
        lava_docker_slave.sh -a <action> -p <prefix> -n <name> -v <version> -t <type> -x <proxy> -m <master>
    DESCRIPTION
        -a:     specify action of this script
        -p:     prefix of worker name, fill in site please
        -n:     unique name for user to distinguish other worker
        -v:     version of lava dispatcher, e.g. 2019.01, 2019.03, etc
        -t:     type of lava slave image, available: android, linux
        -x:     local http proxy, e.g. http://apac.nics.nxp.com, http://emea.nics.nxp.com:8080, http://amec.nics.nxp.com:8080
        -m:     the master this slave will connect to

        Example:
        build:   can skip this if want to use prebuilt customized docker image on dockerhub
                 lava_docker_slave.sh -a build -v 2019.03 -t android -x http://apac.nics.nxp.com:8080
        start:   new/start a lava docker slave
                 lava_docker_slave.sh -a start -p shanghai -n apple -v 2019.03 -t android -x http://apac.nics.nxp.com:8080 -m 10.192.225.2
        stop:    stop a lava docker slave
                 lava_docker_slave.sh -a stop -p shanghai -n apple
        destroy: destroy a lava docker slave
                 lava_docker_slave.sh -a destroy -p shanghai -n apple
        (Here, if docker host name is shubuntu1, then lava worker name will be shanghai-shubuntu1-docker-apple)

(The End)