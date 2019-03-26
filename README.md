## Introduction

This is an extend docker slave image based on lava official docker image.<br />
We extend this because Lava's official docker image have some limits, e.g.

* For android, only one device could be linked to one machine if use official docker image, otherwise, simultaneous apt operation in one container will encountered apt lock issue.
* For linux, official guy suggest to configure nfs, tftp in host which make the operation not fluent for a big farm.

So this extend targets for resolve these issues until official guy give any better solution.

Now, it just support android.

#### a) What changed for android base image?

As in lava docker official slave image, lxc-mocker no longer play the role to separate the environment for different devices, so we will use multi-docker-container to do it.

That means, for every single docker container, just one device could be linked into one docker container. **Don't** try to link more than one device to one container, it will make apt operation conflict for multiple jobs.

At last, an enhanced `lava_lxc_device_add.py` had to be added to image to make device dynamic been seen in different docker container, otherwise adb in one container may grab all android devices for other containers.



## Prerequisites

>     OS: Linux distribution, 64 bits, recommendation >= ubuntu14.04, centos7.3
>     Kernel Version >= 3.10
>     Docker: Enabled
>     SSH: Enabled

**NOTE**: You can use `curl https://get.docker.com/ | sudo sh` to install docker or visit [docker official website](https://docs.docker.com/install/linux/docker-ce/ubuntu/) to get the latest guide.

## Slave Control Script

The slave script (`lava_docker_slave.sh`) could be executed with root permission or use `sudo usermod -aG docker $USER` to grants privileges to current user. You can use `./lava_docker_slave.sh` to get the usage of this install script, similar to next:

    NAME
            lava_docker_slave.sh - lava android docker slave install script
    SYNOPSIS
            lava_docker_slave.sh -a <action> -p <prefix> -n <name> -v <version> -x <proxy> -m <master>
    DESCRIPTION
            -a:     specify action of this script
            -p:     prefix of worker name, fill in site please
            -n:     unique name for user to distinguish other worker
            -v:     version of lava dispatcher, e.g. 2019.01, 2019.03, etc
            -x:     local http proxy, e.g. http://apac.nics.nxp.com, http://emea.nics.nxp.com:8080, http://amec.nics.nxp.com:8080
            -m:     the master this slave will connect to

            Example:
            build:   can skip this if want to use prebuilt customized docker image on dockerhub
                     lava_docker_slave.sh -a build -v 2019.03 -x http://apac.nics.nxp.com:8080
            start:   new/start a lava docker slave
                     lava_docker_slave.sh -a start -p shanghai -n orange -v 2019.03 -x http://apac.nics.nxp.com:8080 -m 10.192.225.2
            stop:    stop a lava docker slave
                     lava_docker_slave.sh -a stop -p shanghai -n apple
            destroy: destroy a lava docker slave
                     lava_docker_slave.sh -a destroy -p shanghai -n apple
            (Here, if docker host name is shubuntu1, then lava worker name will be shanghai-shubuntu1-docker-apple)


(The End)
