#use armv7hf compatible base image
FROM balenalib/armv7hf-debian:buster-20191223

#dynamic build arguments coming from the /hooks/build file
ARG BUILD_DATE
ARG VCS_REF

#metadata labels
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/HilscherAutomation/netPI-nodered-fieldbus" \
      org.label-schema.vcs-ref=$VCS_REF

#enable building ARM container on x86 machinery on the web (comment out next line if built on Raspberry) 
RUN [ "cross-build-start" ]

#version
ENV HILSCHERNETPI_NODERED_FB_VERSION 1.3.0

#labeling
LABEL maintainer="netpi@hilscher.com" \ 
      version=$HILSCHERNETPI_NODERED_FB_VERSION \
      description="Node-RED with Fieldbus Nodes for netPI RTE 3 (and Pi 3 + NHAT 52-RTE)"

#copy files
COPY "./init.d/*" /etc/init.d/
COPY "./node-red-contrib-fieldbus/*" "./node-red-contrib-fieldbus/lib/*" "./firmwares/*" "./driver/*" "./web-configurator-fieldbus/*" "./driver/includes/" /tmp/

#do installation
RUN apt-get update  \
    && apt-get install curl libboost-filesystem-dev libboost-date-time-dev libjansson-dev p7zip-full build-essential python-dev
#install node.js V8.x.x
RUN curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -  \
    && apt-get install -y nodejs
#install Node-RED
RUN npm install -g --unsafe-perm node-red@1.2.2 \
#install netx driver
    && dpkg -i /tmp/netx-docker-pi-drv-2.0.1-r0.deb \
    && ln -s /usr/lib/libcifx.so /usr/lib/libcifx.so.1 \
    && sed -i -e 's;ChunkSize=0;ChunkSize=250;' /opt/cifx/plugins/netx-spm/config0 \
#compile program checking whether we are running on netPI RTE 3 or on Pi with NHAT 52-RTE
    && cp /tmp/*.h /usr/include/cifx \
    && mv /tmp/checkdevicetype.c /opt/cifx \
    && gcc /opt/cifx/checkdevicetype.c -o /opt/cifx/checkdevicetype -I /usr/include/cifx -lcifx \
    && chmod +x /opt/cifx/checkdevicetype \
#install web fieldbus configurator
    && 7z -t7z -r -v: x "/tmp/WebConfigurator_V1.0200.1358_mod.7z" -o/usr/lib/node_modules \
    && mv "/usr/lib/node_modules/WebConfigurator V1.0200.1358" "/usr/lib/node_modules/WebConfigurator" \
    && cd /usr/lib/node_modules/WebConfigurator/ServerContent/ \
    && npm install \
#make some changes in the fielbus configurator setup file
    && sed -i -e 's;"uiHost": "127.0.0.1";\"uiHost": "";' ServerSettings.json \
    && sed -i -e 's;"configuration-file-path": "/opt/node-red/.userdir";\"configuration-file-path": "/root/.node-red/";' ServerSettings.json \
    && sed -i -e 's;"platform": "ntijcxgb";\"platform": "npi3";' ServerSettings.json \
#install fieldbus nodes
    && mkdir /root/.node-red \
    && mv /tmp/fieldbusSettings.json /root/.node-red \
    && mkdir -p /usr/lib/node_modules/fieldbus/lib \
    && mv /tmp/10-fieldbus.html /tmp/10-fieldbus.js /tmp/package.json -t /usr/lib/node_modules/fieldbus \
    && mv /tmp/fieldbusConnectionPool.js /tmp/fieldbusHandler.js /tmp/HilscherLog.js /tmp/HilscherToolBox.js /usr/lib/node_modules/fieldbus/lib \
    && cd /usr/lib/node_modules/fieldbus \
    && npm install \
    && cd /root/.node-red \
    && npm rebuild \
#install fieldbus nodes wrapper library and generate needed libboost links
    && mv /tmp/fieldbus.node /usr/lib/node_modules/fieldbus/lib \
    && ln -s /usr/lib/arm-linux-gnueabihf/libboost_filesystem.so /usr/lib/arm-linux-gnueabihf/libboost_filesystem.so.1.64.0 \
    && ln -s /usr/lib/arm-linux-gnueabihf/libboost_system.so /usr/lib/arm-linux-gnueabihf/libboost_system.so.1.64.0 \
#install netx firmwares from zip
    && mkdir /opt/cifx/deviceconfig/FW/channel0 \
    && 7z -tzip -r -v: x "/tmp/FWPool.zip" -o/root/.node-red \
#clean up
    && rm -rf /tmp/* \
    && apt-get remove p7zip-full curl \
    && apt-get -yqq autoremove \
    && apt-get -y clean \
    && rm -rf /var/lib/apt/lists/* 

#set the entrypoint
ENTRYPOINT ["/etc/init.d/entrypoint.sh"]

#Node-RED and fieldbus web configurator ports
EXPOSE 1880 9000

#set STOPSGINAL
STOPSIGNAL SIGTERM

#stop processing ARM emulation (comment out next line if built on Raspberry)
RUN [ "cross-build-end" ]
