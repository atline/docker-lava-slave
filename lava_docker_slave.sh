#!/bin/bash

function usage()
{
    cat<<-HELPDOC
NAME
        $(basename $0) - lava android docker slave install script
SYNOPSIS
        $(basename $0) -a <action> -p <prefix> -n <name> -v <version> -x <proxy> -m <master>
DESCRIPTION
        -a:     specify action of this script
        -p:     prefix of worker name, fill in site please
        -n:     unique name for user to distinguish other worker
        -v:     version of lava dispatcher, e.g. 2019.01, 2019.03, etc
        -x:     local http proxy, e.g. http://apac.nics.nxp.com, http://emea.nics.nxp.com:8080, http://amec.nics.nxp.com:8080
        -m:     the master this slave will connect to

        Example:
        build:   can skip this if want to use prebuilt customized docker image on dockerhub
                 $(basename $0) -a build -v 2019.03 -x http://apac.nics.nxp.com:8080
        start:   new/start a lava docker slave
                 $(basename $0) -a start -p shanghai -n orange -v 2019.03 -x http://apac.nics.nxp.com:8080 -m 10.192.225.2
        stop:    stop a lava docker slave
                 $(basename $0) -a stop -p shanghai -n apple
        destroy: destroy a lava docker slave
                 $(basename $0) -a destroy -p shanghai -n apple
        (Here, if docker host name is shubuntu1, then lava worker name will be shanghai-shubuntu1-docker-apple)
HELPDOC
}

# get options
parsed_args=$(getopt -o a:p:n:v:x:m: -n $(basename $0) -- "$@")
if [ 0 -ne $? ]; then
    usage
    exit 1
fi
eval set -- "${parsed_args}"
if [[ '--' == $1 ]]; then
    usage
    exit 1
fi

# parse options
while true
do
    case "$1" in
        -a)
            action=$2
            shift 2
            ;;
        -p)
            prefix=$2
            shift 2
            ;;
        -n)
            name=$2
            shift 2
            ;;
        -v)
            version=$2
            shift 2
            ;;
        -x)
            proxy=$2
            shift 2
            ;;
        -m)
            master=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Fatal: parameter error."
            usage
            exit 1
    esac
done

http_proxy=$proxy
dispatcher_hostname=--hostname=$prefix-$(hostname)-docker-$name
logger_url=tcp://$master:5555
master_url=tcp://$master:5556
container_name=$prefix-$(hostname)-docker-$name

# start logic with different actions
case "$action" in
    build)
        if [[ ! $version || ! $proxy ]]; then
            echo "Fatal: -v, -x required for build!"
            usage
            exit 1
        fi

        docker build \
            --build-arg build_from=$version \
            --build-arg http_proxy=$http_proxy \
            --no-cache \
            -t lava-dispatcher-android:$version .
        ;;

    start)
        if [[ ! $prefix || ! $name || ! $version || ! $proxy || ! $master ]]; then
            echo "Fatal: -p, -n, -v, -x, -m required for start!"
            usage
            exit 1
        fi

        status=$(docker inspect --format '{{ .State.Status }}' $container_name 2>&1)
        if [[ $? -eq 0 ]]; then
            if [[ $status == 'exited' ]]; then
                echo "Slave existed, start it for you now."
                rm -fr ~/.lava/$container_name
                docker start $container_name
            else
                echo "Slave already running, no action perform."
            fi
        else
            echo "Slave not exist, set a new for you now."

            no=$(docker images -q lava-dispatcher-android:$version | wc -l)
            if [[ $no -eq 0 ]]; then
                echo "No local docker image found, use prebuilt image on dockerhub."
                target_image=atline/lava-dispatcher-android:$version
            else
                echo "Use local built docker image."
                target_image=lava-dispatcher-android:$version
            fi

            rm -fr ~/.lava/$container_name
            docker run -d --privileged \
                -v /dev:/dev \
                -v ~/.lava/$container_name:/dev/bus/usb \
                -v /dev/bus/usb:/lava_usb_bus \
                -v /labScripts:/labScripts \
                -v /local/lava-ref-binaries:/local/lava-ref-binaries \
                -e DISPATCHER_HOSTNAME=$dispatcher_hostname \
                -e LOGGER_URL=$logger_url \
                -e MASTER_URL=$master_url \
                -e http_proxy=$proxy \
                --name $container_name \
                $target_image
        fi
        ;;

    stop)
        if [[ ! $prefix || ! $name ]]; then
            echo "Fatal: -p, -n required for stop!"
            usage
            exit 1
        fi

        docker stop $container_name
        ;;

    destroy)
        if [[ ! $prefix || ! $name ]]; then
            echo "Fatal: -p, -n required for destroy!"
            usage
            exit 1
        fi

        docker rm -f $container_name
        ;;

    *)
        echo "Fatal: Unsupported action."
        usage
        exit 1
esac
