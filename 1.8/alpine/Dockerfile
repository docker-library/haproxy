### haproxy source build ###
FROM alpine:3.6 as build

ENV HAPROXY_MAJOR 1.8
ENV HAPROXY_VERSION 1.8.4
ENV HAPROXY_MD5 540cd21169e8828d5d11894b2fa74ab4
ENV LUA_VERSION=5.3.4
ENV LUA_SHA1=79790cfd40e09ba796b01a571d4d63b52b1cd950

RUN set -ex ;\
    apk add --no-cache --virtual .build-deps ca-certificates gcc libc-dev linux-headers make openssl openssl-dev pcre-dev readline-dev tar zlib-dev ;\
    wget -O lua.tar.gz "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz" ;\
	  echo "$LUA_SHA1 *lua.tar.gz" | sha1sum -c ;\
	  mkdir -p /usr/src/lua ;\
	  tar -xzf lua.tar.gz -C /usr/src/lua --strip-components=1 ;\
	  make -C /usr/src/lua -j "$(getconf _NPROCESSORS_ONLN)" linux ;\
	  make -C /usr/src/lua install;\
	  wget -O haproxy.tar.gz "https://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" ;\
	  echo "$HAPROXY_MD5 *haproxy.tar.gz" | md5sum -c ;\
	  mkdir -p /usr/src/haproxy ;\
	  tar -xzf haproxy.tar.gz -C /usr/src/haproxy --strip-components=1 ;\
    makeOpts='TARGET=linux2628 USE_LUA=1 LUA_INC=/usr/local/lua-install/inc LUA_LIB=/usr/local/lua-install/lib USE_OPENSSL=1 USE_PCRE=1 PCREDIR= USE_ZLIB=1' ;\
	  make -C /usr/src/haproxy -j "$(getconf _NPROCESSORS_ONLN)" all $makeOpts ;\
	  make -C /usr/src/haproxy install-bin $makeOpts ;\
	  runDeps="$(scanelf --needed --nobanner --format '%n#p' --recursive /usr/local | tr ',' '\n' | sort -u | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }')" ;\
	  apk add --virtual .haproxy-rundeps $runDeps ;\
    mkdir -p /files/usr/local/etc/haproxy /files/usr/local/sbin/ ;\
    cp -R /usr/src/haproxy/examples/errorfiles /files/usr/local/etc/haproxy/errors ;\
    cp /usr/local/sbin/haproxy /files/usr/local/sbin/

### haproxy runtime build ###ß
FROM alpine:3.7

COPY --from=build /files /
COPY docker-entrypoint.sh /

RUN set -ex ;\
    apk update ;\
    apk upgrade ;\
    apk add --no-cache su-exec haproxy openssl ca-certificates ;\
    rm -rf /var/cache/apk/*

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
