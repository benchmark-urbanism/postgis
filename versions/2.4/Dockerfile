FROM debian:jessie

MAINTAINER garethsimons@me.com

RUN groupadd -r postgres && useradd -r -g postgres postgres

# setup gosu for use from entrypoint script
ENV GOSU_VERSION 1.10
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

# set locale
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8

# install Postgres etc
RUN apt-get update \

    # postgres & supporting libraries for postgis et al
    && apt-get install --no-install-recommends -y build-essential cmake ca-certificates wget bzip2 \
    && touch /etc/apt/sources.list.d/pgdg.list \
    && echo "deb http://apt.postgresql.org/pub/repos/apt jessie-pgdg main" >> /etc/apt/sources.list.d/pgdg.list \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-9.6 \
        libproj-dev \
        libgdal-dev \
        libxml2-dev \
        libjson-c-dev \
        libcgal-dev \
        libboost-dev \
        libmpfr-dev \
        libgmp-dev \
        libpcre3-dev \
        postgresql-contrib \
        postgresql-server-dev-all

# geos 3.6.2
ENV GEOS_VERSION 3.6.2
RUN wget -O geos.tar.bz2 http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2 \
    && bzip2 -d geos.tar.bz2 \
    && tar -xf geos.tar \
    && cd geos-$GEOS_VERSION \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -r geos-$GEOS_VERSION geos.tar

# SFCGAL
ENV SFCGAL_VERSION 1.3.1
RUN wget -O sfcgal.tar.gz https://github.com/Oslandia/SFCGAL/archive/v$SFCGAL_VERSION.tar.gz \
    && tar xf sfcgal.tar.gz \
    && cd SFCGAL-$SFCGAL_VERSION \
    && cmake . \
    && make \
    && make install \
    && cd .. \
    && rm -r SFCGAL-$SFCGAL_VERSION sfcgal.tar.gz

# postGIS
ENV POSTGIS_VERSION 2.4.0dev
RUN wget -O postgis.tar.gz http://postgis.net/stuff/postgis-$POSTGIS_VERSION.tar.gz \
    && tar xf postgis.tar.gz \
    && cd postgis-$POSTGIS_VERSION \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -r postgis-$POSTGIS_VERSION postgis.tar.gz

# pgrouting (requires build directory)
ENV PGROUTING_VERSION 2.4.1
RUN wget -O pgrouting.tar.gz https://github.com/pgRouting/pgrouting/archive/v$PGROUTING_VERSION.tar.gz \
    && tar xf pgrouting.tar.gz \
    && cd pgrouting-$PGROUTING_VERSION \
    && mkdir build_dir \
    && cd build_dir \
    && cmake .. \
    && make \
    && make install \
    && cd ../.. \
    && rm -r pgrouting-$PGROUTING_VERSION pgrouting.tar.gz

# cleanup
RUN apt-get purge -y --auto-remove build-essential cmake ca-certificates wget bzip2 \
    && rm -rf /var/lib/apt/lists/*

# copy scripts
ADD scripts /scripts
RUN chmod -R 0755 /scripts

# make directories for linking against
RUN mkdir -p /postgresql/9.6/main \
    && mkdir -p /postgresql/9.6/ssl

EXPOSE 5432

VOLUME ["/postgresql/9.6/main", "/postgresql/9.6/ssl"]

CMD /scripts/db_start.sh