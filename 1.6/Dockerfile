FROM debian:jessie

RUN apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys AEF2348766F371C689A7360095A42FE8353525F9

ENV HAPROXY_MAJOR 1.6

RUN echo "deb http://httpredir.debian.org/debian jessie-backports main" > /etc/apt/sources.list.d/backports.list \
    && echo "deb http://haproxy.debian.net jessie-backports-${HAPROXY_MAJOR} main" > /etc/apt/sources.list.d/haproxy.list

RUN apt-get update \
    && apt-get install haproxy -y -t jessie-backports-${HAPROXY_MAJOR} \
    && rm -rf /var/lib/apt/lists/*

CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
