FROM debian:jessie

MAINTAINER garethsimons@me.com

RUN groupadd -r postgres && useradd -r -g postgres postgres

ENV GOSU_VERSION 1.9
RUN set -x \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates wget \
    && rm -rf /var/lib/apt/lists/* \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
    && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && apt-get purge -y --auto-remove ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8 \

# install Postgres etc.
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt jessie-pgdg main" >> /etc/apt/sources.list' \
    && gpg --keyserver pgpkeys.mit.edu --recv-key 7FCC7D46ACCC4CF8 \
    && gpg -a --export 7FCC7D46ACCC4CF8 | apt-key add - \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        gdal-bin postgresql-9.6 \
        postgresql-contrib-9.6 \
        postgresql-9.6-postgis-2.3 \
        postgresql-9.6-postgis-2.3-scripts \
        postgresql-9.6-pgrouting \
    && rm -rf /var/lib/apt/lists/*

ADD scripts /scripts
RUN chmod -R 0755 /scripts

RUN mkdir -p /postgresql/9.6/main \
    && mkdir -p /postgresql/9.6/ssl

EXPOSE 5432

VOLUME ["/postgresql/9.6/main", "/postgresql/9.6/ssl"]

CMD /scripts/db_start.sh