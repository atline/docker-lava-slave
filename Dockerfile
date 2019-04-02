ARG build_from
ARG http_proxy

FROM lavasoftware/lava-dispatcher:$build_from

COPY ["lava_lxc_device_add.py", "/usr/share/lava-dispatcher/lava_lxc_device_add.py"]
COPY ["lava-coordinator.conf", "/etc/lava-coordinator/lava-coordinator.conf"]

RUN sed -i 's/^.*upgrade/#&/g' /usr/bin/lxc-create;\
sed -i '/containers/{n;s/^.*/#&/g;}' /etc/init.d/udev;\
sed -i 's/^\s\s*warn_if_interactive/:/g' /etc/init.d/udev;\
sed -i '/\/etc\/lava-dispatcher\/lava-slave/i\set +e\ngrep "export http_proxy=\$http_proxy" /etc/lava-dispatcher/lava-slave\nrc=$?\nset -e\nif [ $rc -ne 0 ]; then\necho "export http_proxy=\$http_proxy" >> /etc/lava-dispatcher/lava-slave\nfi\nsed -i "s/\\"coordinator_hostname\\": .*/\\"coordinator_hostname\\": \\"$master\\"/g" /etc/lava-coordinator/lava-coordinator.conf' /root/entrypoint.sh;\
sed -i '/\/usr\/bin\/lava-slave/i\service udev start' /root/entrypoint.sh;\
apt-get update;\
apt-get install -y lavacli;\
apt-get install -y vim --no-install-recommends;\
apt-get install -y python3-pip --no-install-recommends;\
pip3 install pyserial;\
chmod 777 /usr/share/lava-dispatcher/lava_lxc_device_add.py
