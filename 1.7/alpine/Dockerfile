#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

FROM alpine:3.12

# roughly, https://git.alpinelinux.org/aports/tree/main/haproxy/haproxy.pre-install?h=3.12-stable
RUN set -eux; \
	addgroup --gid 99 --system haproxy; \
	adduser \
		--disabled-password \
		--home /var/lib/haproxy \
		--ingroup haproxy \
		--no-create-home \
		--system \
		--uid 99 \
		haproxy

ENV HAPROXY_VERSION 1.7.13
ENV HAPROXY_URL https://www.haproxy.org/download/1.7/src/haproxy-1.7.13.tar.gz
ENV HAPROXY_SHA256 53ae3ae722236a56cc8b584bf1f8ef422fc40e9ce032d244e256c486c1713600

# see https://sources.debian.net/src/haproxy/jessie/debian/rules/ for some helpful navigation of the possible "make" arguments
RUN set -eux; \
	\
	apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		linux-headers \
		lua5.3-dev \
		make \
		openssl \
		openssl-dev \
		pcre2-dev \
		readline-dev \
		tar \
		zlib-dev \
	; \
	\
	wget -O haproxy.tar.gz "$HAPROXY_URL"; \
	echo "$HAPROXY_SHA256 *haproxy.tar.gz" | sha256sum -c; \
	mkdir -p /usr/src/haproxy; \
	tar -xzf haproxy.tar.gz -C /usr/src/haproxy --strip-components=1; \
	rm haproxy.tar.gz; \
	\
# https://github.com/haproxy/haproxy/issues/760#issuecomment-804282562
	apk add --no-cache --virtual .build-deps-patch patch; \
# https://git.haproxy.org/?p=haproxy-1.7.git;a=commit;h=3280d0ab43e03ae5e94da205630fa576d7633627
	wget -O ebtree.patch 'https://git.haproxy.org/?p=haproxy-1.7.git;a=patch;h=3280d0ab43e03ae5e94da205630fa576d7633627'; \
	echo '8c8176604a9638d57fc4385154d8d2622d4ae52422ea53a5b91fac49459cfd2d *ebtree.patch' | sha256sum -c -; \
	patch -p1 --input="$PWD/ebtree.patch" --directory=/usr/src/haproxy; \
	apk del --no-network .build-deps-patch; \
	\
	makeOpts=' \
		CFLAGS+="-Wno-address-of-packed-member" \
		TARGET=linux2628 \
		USE_GETADDRINFO=1 \
		USE_LUA=1 LUA_INC=/usr/include/lua5.3 LUA_LIB=/usr/lib/lua5.3 \
		USE_OPENSSL=1 \
		USE_PCRE2=1 USE_PCRE2_JIT=1 \
		USE_ZLIB=1 \
		\
		EXTRA_OBJS=" \
		" \
	'; \
	\
	nproc="$(getconf _NPROCESSORS_ONLN)"; \
	eval "make -C /usr/src/haproxy -j '$nproc' all $makeOpts"; \
	eval "make -C /usr/src/haproxy install-bin $makeOpts"; \
	\
	mkdir -p /usr/local/etc/haproxy; \
	cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors; \
	rm -rf /usr/src/haproxy; \
	\
	runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)"; \
	apk add --no-network --virtual .haproxy-rundeps $runDeps; \
	apk del --no-network .build-deps; \
	\
# smoke test
	haproxy -v

# https://www.haproxy.org/download/1.8/doc/management.txt
# "4. Stopping and restarting HAProxy"
# "when the SIGTERM signal is sent to the haproxy process, it immediately quits and all established connections are closed"
# "graceful stop is triggered when the SIGUSR1 signal is sent to the haproxy process"
STOPSIGNAL SIGUSR1

COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat
ENTRYPOINT ["docker-entrypoint.sh"]

# no USER for backwards compatibility (to try to avoid breaking existing users)
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
