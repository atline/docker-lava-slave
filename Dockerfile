ARG build_from

FROM lavasoftware/lava-dispatcher:$build_from

ENV LC_CTYPE C.UTF-8
ENV LC_ALL C.UTF-8
ENV LANG C

COPY ["lava-coordinator.conf", "/etc/lava-coordinator/lava-coordinator.conf"]
COPY ["customized.sh", "/root/entrypoint.d/"]

RUN sed -i 's/^.*upgrade/#&/g' /usr/bin/lxc-create;\
sed -i '/containers/{n;s/^.*/#&/g;}' /etc/init.d/udev;\
sed -i 's/^\s\s*warn_if_interactive/:/g' /etc/init.d/udev;\
sed -i '/\/etc\/lava-dispatcher\/lava-worker/i\set +e\ngrep "export http_proxy=\$http_proxy" /etc/lava-dispatcher/lava-worker\nrc=$?\nset -e\nif [ $rc -ne 0 ]; then\necho "export http_proxy=\$http_proxy" >> /etc/lava-dispatcher/lava-worker\nfi\nsed -i "s/\\"coordinator_hostname\\": .*/\\"coordinator_hostname\\": \\"$master\\"/g" /etc/lava-coordinator/lava-coordinator.conf' /root/entrypoint.sh;\
sed -i '/\/usr\/bin\/lava-slave/i\service udev start\nservice ser2net start' /root/entrypoint.sh;\
sed -i '/killproc -p/a\rm -f \$PIDFILE || true' /etc/init.d/ser2net;\
apt-get update;\
apt-get install -y nfs-kernel-server rpcbind --no-install-recommends;\
apt-get install -y python3-pip --no-install-recommends;\
apt-get install -y lavacli;\
apt-get install -y vim wget --no-install-recommends;\
rm -rf /var/lib/apt/lists/*;\
pip3 install pyserial;\
lava-dispatcher-host rules install;\
wget --no-check-certificate -O /bin/uuu https://github.com/NXPmicro/mfgtools/releases/download/uuu_1.3.191/uuu;\
chmod +x /bin/uuu; \
chmod +x /root/entrypoint.d/customized.sh

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]
CMD ["/root/entrypoint.sh"]
