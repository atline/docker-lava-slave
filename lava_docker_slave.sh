#!/bin/bash -e

function usage()
{
    cat<<-HELPDOC
NAME
        $(basename "$0") - lava docker slave install script
SYNOPSIS
        $(basename "$0") -a <action> -p <prefix> -n <name> -v <version> -t <type> -x <proxy> -m <master>
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
                 $(basename "$0") -a build -v 2019.03 -t android -x http://apac.nics.nxp.com:8080
        start:   new/start a lava docker slave
                 $(basename "$0") -a start -p shanghai -n apple -v 2019.03 -t android -x http://apac.nics.nxp.com:8080 -m 10.192.225.2
        stop:    stop a lava docker slave
                 $(basename "$0") -a stop -p shanghai -n apple
        destroy: destroy a lava docker slave
                 $(basename "$0") -a destroy -p shanghai -n apple
        (Here, if docker host name is shubuntu1, then lava worker name will be shanghai-shubuntu1-docker-apple)
HELPDOC
}

# get timezone
function get_timezone()
{
    timezone=$(find /usr/share/zoneinfo/ -type f | xargs md5sum | \
        grep $(md5sum /etc/localtime | cut -d ' ' -f1) | \
        awk -F '/usr/share/zoneinfo/' '{print $2}' | tail -1)
}

# get options
set +e
parsed_args=$(getopt -o a:p:n:v:t:x:m: -n "$(basename "$0")" -- "$@")
rc=$?
set -e
if [ 0 -ne $rc ]; then
    usage
    exit 1
fi
eval set -- "${parsed_args}"
if [[ '--' == "$1" ]]; then
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
        -t)
            typ=$2
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

declare CUR_DIR="$(cd "$(dirname "$0")"; pwd -P)"

get_timezone

# parse advanced configure
volume_string=""
no_proxy=".sw.nxp.com,.freescale.net,10.0.0.0/8"
if [ -f $CUR_DIR/advanced.json ]; then
    volume=$(candidate=$(cat $CUR_DIR/advanced.json) \
        docker run --rm -e candidate endeveit/docker-jq \
        sh -c 'echo "$candidate" | jq -r ". | select(.volume != null) | .volume[]"')

    for per_volume in $volume
    do
        volume_string="$volume_string -v $per_volume"
    done

    no_proxy=$(candidate=$(cat $CUR_DIR/advanced.json) \
        docker run --rm -e candidate endeveit/docker-jq \
        sh -c 'echo "$candidate" | jq -r ". | select(.no_proxy != null) | .no_proxy"')
fi

# start logic with different actions

case "$action" in
    build)
        if [[ ! $version || ! $typ || ! $proxy ]]; then
            echo "Fatal: -v, -t, -x required for build!"
            usage
            exit 1
        fi

        docker build \
            --build-arg build_from="$version" \
            --build-arg http_proxy="$http_proxy" \
            --no-cache \
            -t lava-dispatcher-"$typ":"$version" -f Dockerfile."$typ" .
        ;;

    start)
        if [[ ! $prefix || ! $name || ! $version || ! $typ || ! $proxy || ! $master ]]; then
            echo "Fatal: -p, -n, -v, -t, -x, -m required for start!"
            usage
            exit 1
        fi

        set +e
        status=$(docker inspect --format '{{ .State.Status }}' "$container_name" 2>&1)
        rc=$?
        set -e
        if [[ $rc -eq 0 ]]; then
            if [[ $status == 'exited' ]]; then
                echo "Slave existed, start it for you now."
                if [[ $typ == "android" ]]; then
                    echo "Try to stop adb server on host..."
                    sudo adb kill-server > /dev/null 2>&1
                    sudo rm -fr ~/.lava/"$container_name"/dumb && \
                        mkdir -p ~/.lava/"$container_name"/dumb && \
                        touch ~/.lava/"$container_name"/ser2net.conf
                elif [[ $typ == "linux" ]]; then
                    echo "Try to stop tftp & nfs service on host..."
                    sudo modprobe nfsd
                    sudo service tftpd-hpa stop > /dev/null 2>&1 || true
                    sudo service rpcbind stop > /dev/null 2>&1 || true
                    sudo service nfs-kernel-server stop > /dev/null 2>&1 || true
                    sudo start-stop-daemon --stop --oknodo --quiet --name rpc.mountd --user 0 > /dev/null 2>&1 || true
                    sudo start-stop-daemon --stop --oknodo --quiet --name rpc.svcgssd --user 0 > /dev/null 2>&1 || true
                    sudo start-stop-daemon --stop --oknodo --quiet --name nfsd --user 0 --signal 2 > /dev/null 2>&1 || true
                    mkdir -p ~/.lava/"$container_name" && touch ~/.lava/"$container_name"/ser2net.conf
                fi
                docker start "$container_name"
            else
                echo "Slave already running, no action perform."
            fi
        else
            echo "Slave not exist, set a new for you now."

            no=$(docker images -q lava-dispatcher-"$typ":"$version" | wc -l)
            if [[ $no -eq 0 ]]; then
                echo "No local docker image found, use prebuilt image on dockerhub."
                target_image=atline/lava-dispatcher-$typ:$version
            else
                echo "Use local built docker image."
                target_image=lava-dispatcher-$typ:$version
            fi

            mkdir -p ~/.config
            touch ~/.config/lavacli.yaml
            if [ ! -s ~/.config/lavacli.yaml ]; then
                echo "{}" > ~/.config/lavacli.yaml
            fi

            if [[ $typ == "android" ]]; then
                echo "Try to stop adb server on host..."
                sudo adb kill-server > /dev/null 2>&1
                sudo rm -fr ~/.lava/"$container_name"/dumb && \
                    mkdir -p ~/.lava/"$container_name"/dumb && \
                    touch ~/.lava/"$container_name"/ser2net.conf
                docker run -d --privileged \
                    -v /dev:/dev \
                    -v ~/.lava/"$container_name"/dumb:/dev/bus/usb \
                    -v /dev/bus/usb:/lava_usb_bus \
                    -v /labScripts:/labScripts \
                    -v /local/lava-ref-binaries:/local/lava-ref-binaries \
                    -v ~/.lava/"$container_name"/ser2net.conf:/etc/ser2net.conf \
                    -v ~/.config/lavacli.yaml:/root/.config/lavacli.yaml \
                    $volume_string \
                    -e DISPATCHER_HOSTNAME="$dispatcher_hostname" \
                    -e LOGGER_URL="$logger_url" \
                    -e MASTER_URL="$master_url" \
                    -e TZ="$timezone" \
                    -e http_proxy="$proxy" \
                    -e no_proxy="$no_proxy" \
                    -e master="$master" \
                    --name "$container_name" \
                    "$target_image"
            elif [[ $typ == "linux" ]]; then
                echo "Try to stop tftp & nfs service on host..."
                sudo modprobe nfsd
                sudo service tftpd-hpa stop > /dev/null 2>&1 || true
                sudo service rpcbind stop > /dev/null 2>&1 || true
                sudo service nfs-kernel-server stop > /dev/null 2>&1 || true
                sudo start-stop-daemon --stop --oknodo --quiet --name rpc.mountd --user 0 > /dev/null 2>&1 || true
                sudo start-stop-daemon --stop --oknodo --quiet --name rpc.svcgssd --user 0 > /dev/null 2>&1 || true
                sudo start-stop-daemon --stop --oknodo --quiet --name nfsd --user 0 --signal 2 > /dev/null 2>&1 || true
                mkdir -p ~/.lava/"$container_name" && touch ~/.lava/"$container_name"/ser2net.conf
                docker run -d --net=host --privileged \
                    -v /dev:/dev \
                    -v /labScripts:/labScripts \
                    -v /local/lava-ref-binaries:/local/lava-ref-binaries \
                    -v /var/lib/lava/dispatcher/tmp:/var/lib/lava/dispatcher/tmp \
                    -v ~/.config/lavacli.yaml:/root/.config/lavacli.yaml \
                    -v ~/.lava/"$container_name"/ser2net.conf:/etc/ser2net.conf \
                    $volume_string \
                    -e DISPATCHER_HOSTNAME="$dispatcher_hostname" \
                    -e LOGGER_URL="$logger_url" \
                    -e MASTER_URL="$master_url" \
                    -e TZ="$timezone" \
                    -e http_proxy="$proxy" \
                    -e no_proxy="$no_proxy" \
                    -e master="$master" \
                    --name "$container_name" \
                    "$target_image"
            fi
        fi
        ;;

    stop)
        if [[ ! $prefix || ! $name ]]; then
            echo "Fatal: -p, -n required for stop!"
            usage
            exit 1
        fi

        docker stop "$container_name"

        if [[ $typ == "linux" ]]; then
            echo "Start to destory nfs port."
            sudo start-stop-daemon --stop --oknodo --quiet --name rpc.mountd --user 0 > /dev/null 2>&1 || true
            sudo start-stop-daemon --stop --oknodo --quiet --name rpc.svcgssd --user 0 > /dev/null 2>&1 || true
            sudo start-stop-daemon --stop --oknodo --quiet --name nfsd --user 0 --signal 2 > /dev/null 2>&1 || true
        fi
        ;;

    destroy)
        if [[ ! $prefix || ! $name ]]; then
            echo "Fatal: -p, -n required for destroy!"
            usage
            exit 1
        fi

        docker rm -f "$container_name"

        if [[ $typ == "linux" ]]; then
            echo "Start to destory nfs port."
            sudo start-stop-daemon --stop --oknodo --quiet --name rpc.mountd --user 0 > /dev/null 2>&1 || true
            sudo start-stop-daemon --stop --oknodo --quiet --name rpc.svcgssd --user 0 > /dev/null 2>&1 || true
            sudo start-stop-daemon --stop --oknodo --quiet --name nfsd --user 0 --signal 2 > /dev/null 2>&1 || true
        fi
        ;;

    *)
        echo "Fatal: Unsupported action."
        usage
        exit 1
esac

echo "Congratulations, action performed successfully."
