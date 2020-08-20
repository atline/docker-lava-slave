## Introduction

To use docker solution to manage a customized lava lab, we do some extension based on lava official slave image.

### Docker solution advantage:

* Could use any physical linux variant to quick setup a lava slave. (The traditional non-container solution can just work on debian os, additionally just some version of debian)

* Could easily upgrade/downgrade lava slave to any version easily with just one command without feel pain of library conflict.

* As we persist lavacli identity, ser2net configure, and other lab scripts with bind mount, it means upgrade/re-setup lava slave will require nothing from user side to reconfigure.

### Detail solutions:

* _Main extension:_

    * Enable tftp & nfs in container, this makes linux test out of box for use.
    * Enable udev in container, this makes android test out of box for use.
    * Other misc.

* _Limit:_
  * Cannot use host's adb daemon together with this solution.

  * This solution share the network namespace of host, this is because if we use the default docker0 bridge, the container's ip will be an internal ip which cannot not be connected by device when DUT do tftp & nfs operation. So, we choose to share host's network namespace.

    As a result, **only** one container could be active at the same time on physical machine. Meanwhile, the `slave control script` will automatically close host's tftp & nfs for you when start container.

    Sample architecture like follows:

        Physical Machine -> LAVA Container -> Device 1
                                           -> Device 2
                                           -> ...
                                           -> Device N

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
        lava_docker_slave.sh -a <action> -p <prefix> -n <name> -v <version> -x <proxy> -m <master>
    DESCRIPTION
        -a:     specify action of this script
        -p:     prefix of worker name, fill in site please
        -n:     unique name for user to distinguish other worker
        -v:     version of lava dispatcher, e.g. 2020.08, etc
        -x:     local http proxy, e.g. http://apac.nics.nxp.com, http://emea.nics.nxp.com:8080, http://amec.nics.nxp.com:8080
        -m:     the master this slave will connect to

        Example:
        build:   can skip this if want to use prebuilt customized docker image on dockerhub
                 ./lava_docker_slave.sh -a build -v 2020.08 -x http://apac.nics.nxp.com:8080
        start:   new/start a lava docker slave
                 ./lava_docker_slave.sh -a start -p shanghai -n apple -v 2020.08 -x http://apac.nics.nxp.com:8080 -m 10.192.225.2
        stop:    stop a lava docker slave
                 ./lava_docker_slave.sh -a stop -p shanghai -n apple
        destroy: destroy a lava docker slave
                 ./lava_docker_slave.sh -a destroy -p shanghai -n apple
        (Here, if docker host name is shubuntu1, then lava worker name will be shanghai-shubuntu1-docker-apple)

### About advanced.json:

You can define some additional control parameters in `advanced.json` before new a container, this afford you some advanced ability to configure container.

Some parameters' format as follows:

    {
        "volume": ["/host_folder_1:/container_folder_1", "/host_folder_2:/container_folder_2"],
        "no_proxy": ".sw.nxp.com,.freescale.net,10.0.0.0/8",
        "force_update": "true"
    }

NOTE: above paremeters not all necessary, you can pick what you needed.

(The End)
