FROM alpine:3.5

ENV HAPROXY_MAJOR 1.6
ENV HAPROXY_VERSION 1.6.11
ENV HAPROXY_MD5 844da4b553c887833550a008692e7a74
ENV LUA_MAJOR=5.3 \
	LUA_VERSION=5.3.3 \
	LUA_MD5=703f75caa4fdf4a911c1a72e67a27498

# see http://sources.debian.net/src/haproxy/1.5.8-1/debian/rules/ for some helpful navigation of the possible "make" arguments
RUN set -x \
	&& apk add --no-cache --virtual .build-deps \
		curl \
		gcc \
		libc-dev \
		linux-headers \
		make \
		openssl-dev \
		pcre-dev \
		readline-dev \
		zlib-dev \

	# Install Lua
	&& curl -SLR https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz -o lua.tar.gz \
	&& echo "$LUA_MD5  lua.tar.gz" | md5sum -c \
	&& mkdir -p /usr/src \
	&& tar -xzf lua.tar.gz -C /usr/src \
	&& mv "/usr/src/lua-$LUA_VERSION" /usr/src/lua \
	&& rm lua.tar.gz \
	&& make -C /usr/src/lua linux install \

	# Install HAProxy
	&& curl -SL "http://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" -o haproxy.tar.gz \
	&& echo "${HAPROXY_MD5}  haproxy.tar.gz" | md5sum -c \
	&& tar -xzf haproxy.tar.gz -C /usr/src \
	&& mv "/usr/src/haproxy-$HAPROXY_VERSION" /usr/src/haproxy \
	&& rm haproxy.tar.gz \
	&& make -C /usr/src/haproxy \
		TARGET=linux2628 \
		USE_PCRE=1 PCREDIR= \
		USE_OPENSSL=1 \
		USE_ZLIB=1 \
		USE_LUA=1 \
		all \
		install-bin \
	&& mkdir -p /usr/local/etc/haproxy \
	&& cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors \
	&& rm -rf /usr/src/haproxy \
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .haproxy-rundeps $runDeps \
	&& apk del .build-deps

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
