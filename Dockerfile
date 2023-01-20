ARG ALPINE_VERSION=3.17
ARG LIBSIG_VERSION=3.0.3
ARG CARES_VERSION=1.18.1
ARG CURL_VERSION=7.87.0
ARG GEOIP2_PHPEXT_VERSION=1.3.1
ARG XMLRPC_VERSION=01.60.00
ARG LIBTORRENT_VERSION=0.13.8
ARG RTORRENT_VERSION=0.9.8
ARG RUTORRENT_REVISION=06222a00375bdd0f1f1b5b58bda29e7025316428
ARG MKTORRENT_VERSION=1.1
ARG OVERLAY_VERSION=2.2.0.3
ARG BUILDPLATFORM=${BUILDPLATFORM:-linux/amd64}

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS download
RUN apk --update --no-cache add curl git tar xz subversion

ARG OVERLAY_VERSION
WORKDIR /dist/s6
RUN curl -sSL "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" | tar -xz --strip 1

ARG LIBSIG_VERSION
WORKDIR /dist/libsig
RUN curl -sSL "http://ftp.gnome.org/pub/GNOME/sources/libsigc++/3.0/libsigc++-${LIBSIG_VERSION}.tar.xz" | tar -xJ --strip 1

ARG CARES_VERSION
WORKDIR /dist/cares
RUN curl -sSL "https://c-ares.haxx.se/download/c-ares-${CARES_VERSION}.tar.gz" | tar -xz --strip 1

ARG CURL_VERSION
WORKDIR /dist/curl
RUN curl -sSL "https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz" | tar -xz --strip 1

ARG GEOIP2_PHPEXT_VERSION
WORKDIR /dist/geoip2-phpext
RUN git clone -q "https://github.com/rlerdorf/geoip" . && git reset --hard ${GEOIP2_PHPEXT_VERSION} && rm -rf .git

ARG XMLRPC_VERSION
WORKDIR /dist/xmlrpc-c
RUN svn checkout -q "http://svn.code.sf.net/p/xmlrpc-c/code/release_number/${XMLRPC_VERSION}/" . && rm -rf .svn

ARG LIBTORRENT_VERSION
WORKDIR /dist/libtorrent
RUN git clone -q "https://github.com/rakshasa/libtorrent" . && git reset --hard v${LIBTORRENT_VERSION} && rm -rf .git

ARG RTORRENT_VERSION
WORKDIR /dist/rtorrent
RUN git clone -q "https://github.com/rakshasa/rtorrent" . && git reset --hard v${RTORRENT_VERSION} && rm -rf .git

ARG MKTORRENT_VERSION
WORKDIR /dist/mktorrent
RUN git clone -q "https://github.com/esmil/mktorrent" . && git reset --hard v${MKTORRENT_VERSION} && rm -rf .git

ARG RUTORRENT_REVISION
WORKDIR /dist/rutorrent
RUN git clone -q "https://github.com/Novik/ruTorrent" . && git reset --hard $RUTORRENT_REVISION && rm -rf .git
RUN rm -rf conf/users plugins/geoip plugins/_cloudflare share

WORKDIR /dist/rutorrent-geoip2
RUN git clone -q "https://github.com/Micdu70/geoip2-rutorrent" . && rm -rf .git

WORKDIR /dist/rutorrent-filemanager
RUN git clone -q "https://github.com/nelu/rutorrent-filemanager" . && rm -rf .git

WORKDIR /dist/rutorrent-theme-material
RUN git clone -q "https://github.com/TrimmingFool/ruTorrent-MaterialDesign" . && rm -rf .git

WORKDIR /dist/rutorrent-theme-quick
RUN git clone -q "https://github.com/TrimmingFool/club-QuickBox" . && rm -rf .git

WORKDIR /dist/rutorrent-ratio
RUN git clone -q "https://github.com/Gyran/rutorrent-ratiocolor" . && rm -rf .git

WORKDIR /dist/geoip2-rutorrent
RUN git clone -q "https://github.com/Micdu70/geoip2-rutorrent" . && rm -rf .git

WORKDIR /dist/mmdb
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-City.mmdb"
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-Country.mmdb"

ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} AS compile

RUN apk --update --no-cache add \
    autoconf \
    automake \
    binutils \
    brotli-dev \
    build-base \
    cppunit-dev \
    fftw-dev \
    gd-dev \
    geoip-dev \
    libnl3 \
    libnl3-dev \
    libtool \
    libxslt-dev \
    linux-headers \
    ncurses-dev \
    nghttp2-dev \
    openssl-dev \
    pcre-dev \
    php81-dev \
    php81-pear \
    tar \
    tree \
    xz \
    zlib-dev

ENV DIST_PATH="/dist"
COPY --from=download /dist /tmp

WORKDIR /tmp/libsig
RUN ./configure
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/cares
RUN ./configure
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/curl
RUN ./configure \
  --enable-ares \
  --enable-tls-srp \
  --enable-gnu-tls \
  --with-brotli \
  --with-ssl \
  --with-zlib
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/geoip2-phpext
RUN set -e
RUN phpize81
RUN ./configure
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)
RUN cp -f /usr/lib/php81/modules/geoip.so ${DIST_PATH}/usr/lib/php81/modules/

WORKDIR /tmp/xmlrpc-c
RUN ./configure \
   --disable-wininet-client \
   --disable-libwww-client
RUN make -j $(nproc) CXXFLAGS="-flto"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)
RUN mkdir -p ${DIST_PATH}/usr/lib/php81/modules

WORKDIR /tmp/libtorrent
RUN ./autogen.sh
RUN ./configure \
  --with-posix-fallocate
RUN make -j $(nproc) CXXFLAGS="-O2 -flto"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/rtorrent
RUN ./autogen.sh
RUN ./configure \
  --with-xmlrpc-c \
  --with-ncurses
RUN make -j $(nproc) CXXFLAGS="-O2 -flto"
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/mktorrent
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} as builder

COPY --from=compile /dist /
COPY --from=download /dist/s6 /
COPY --from=download /dist/mmdb /var/mmdb
COPY --from=download --chown=nobody:nogroup /dist/rutorrent /var/www/rutorrent
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-material /var/www/rutorrent/plugins/theme/themes/MaterialDesign
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-quick /var/www/rutorrent/plugins/theme/themes/QuickBox
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-ratio /var/www/rutorrent/plugins/ratiocolor
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-filemanager /var/www/rutorrent/plugins/filemanager
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-geoip2 /var/www/rutorrent/plugins/geoip2

ENV PYTHONPATH="$PYTHONPATH:/var/www/rutorrent" \
  S6_BEHAVIOUR_IF_STAGE2_FAILS="2" \
  S6_KILL_GRACETIME="10000" \
  TZ="UTC" \
  PUID="1000" \
  PGID="1000"

RUN echo "@314 http://dl-cdn.alpinelinux.org/alpine/v3.14/main" >> /etc/apk/repositories
RUN apk --update --no-cache add \
    apache2-utils \
    bash \
    bind-tools \
    binutils \
    brotli \
    ca-certificates \
    coreutils \
    dhclient \
    ffmpeg \
    findutils \
    geoip \
    grep \
    gzip \
    libstdc++ \
    mediainfo \
    ncurses \
    nginx \
    nginx-mod-http-headers-more \
    nginx-mod-http-dav-ext \
    nginx-mod-http-geoip2 \
    nginx-mod-rtmp \
    openssl \
    pcre \
    php81 \
    php81-dev \
    php81-bcmath \
    php81-cli \
    php81-ctype \
    php81-curl \
    php81-fpm \
    php81-json \
    php81-mbstring \
    php81-openssl \
    php81-opcache \
    php81-pecl-apcu \
    php81-pear \
    php81-phar \
    php81-posix \
    php81-session \
    php81-sockets \
    php81-xml \
    php81-zip \
    php81-zlib \
    python3 \
    py3-pip \
    p7zip \
    shadow \
    sox \
    tar \
    tzdata \
    unzip \
    unrar@314 \
    util-linux \
    zip \
    zlib \
  && pip3 install --upgrade pip \
  && pip3 install cfscrape cloudscraper \
  && addgroup -g ${PGID} rtorrent \
  && adduser -D -H -u ${PUID} -G rtorrent -s /bin/sh rtorrent \
  && curl --version \
  && rm -rf /tmp/* /var/cache/apk/*

RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    ln -sf /dev/stdout /var/log/php81/access.log && \
    ln -sf /dev/stderr /var/log/php81/error.log

COPY rootfs /

VOLUME [ "/config", "/data", "/passwd" ]

ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=30s --timeout=20s --start-period=10s CMD /usr/local/bin/healthcheck