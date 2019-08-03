FROM debian:buster-slim

MAINTAINER garethsimons@me.com

RUN groupadd -r postgres && useradd -r -g postgres postgres

# install gosu and set locale
RUN apt-get update \
    && apt-get install -y --no-install-recommends locales \
    && rm -rf /var/lib/apt/lists/* \
	&& localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8

# install Postgres etc
ENV POSTGRES_VERSION 11
RUN apt-get update \
    && apt-get install --no-install-recommends -y build-essential gosu gnupg cmake ca-certificates wget bzip2 \
    && touch /etc/apt/sources.list.d/pgdg.list \
    && sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" >> /etc/apt/sources.list.d/pgdg.list' \
    && wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | apt-key add - \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-$POSTGRES_VERSION postgresql-contrib

# geos
ENV GEOS_VERSION 3.7.2
RUN wget -O geos.tar.bz2 http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2 \
    && bzip2 -d geos.tar.bz2 \
    && tar -xf geos.tar \
    && cd geos-$GEOS_VERSION \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -r geos-$GEOS_VERSION geos.tar

# CGAL
ENV CGAL_VERSION 4.13.1
RUN apt-get install -y --no-install-recommends libgmp-dev libmpfr-dev libboost-dev libboost-thread-dev
RUN wget -O cgal.tar.gz https://github.com/CGAL/cgal/releases/download/releases/CGAL-$CGAL_VERSION/CGAL-$CGAL_VERSION.tar.xz \
    && tar xf cgal.tar.gz \
    && cd CGAL-$CGAL_VERSION \
    && cmake . \
    && make \
    && make install \
    && cd .. \
    && rm -r CGAL-$CGAL_VERSION cgal.tar.gz

# SFCGAL
ENV SFCGAL_VERSION 1.3.7
RUN wget -O sfcgal.tar.gz https://github.com/Oslandia/SFCGAL/archive/v$SFCGAL_VERSION.tar.gz \
    && tar xf sfcgal.tar.gz \
    && cd SFCGAL-$SFCGAL_VERSION \
    && cmake . \
    && make \
    && make install \
    && cd .. \
    && rm -r SFCGAL-$SFCGAL_VERSION sfcgal.tar.gz

# postGIS
    # libjson-c-dev libpcre3-dev
ENV POSTGIS_VERSION 2.5.2
RUN apt-get install -y --no-install-recommends postgresql-server-dev-$POSTGRES_VERSION \
    libxml2-dev libproj-dev libgdal-dev
RUN wget -O postgis.tar.gz http://download.osgeo.org/postgis/source/postgis-$POSTGIS_VERSION.tar.gz \
    && tar xf postgis.tar.gz \
    && cd postgis-$POSTGIS_VERSION \
    && ./configure \
    && make \
    && make install \
    && cd .. \
    && rm -r postgis-$POSTGIS_VERSION postgis.tar.gz

# pgrouting (requires build directory)
ENV PGROUTING_VERSION 2.6.2
RUN wget -O pgrouting.tar.gz https://github.com/pgRouting/pgrouting/releases/download/v$PGROUTING_VERSION/pgrouting-$PGROUTING_VERSION.tar.gz \
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
RUN mkdir -p /postgresql/$POSTGRES_VERSION/main \
    && mkdir -p /postgresql/$POSTGRES_VERSION/ssl

EXPOSE 5432

VOLUME ["/postgresql/$POSTGRES_VERSION/main", "/postgresql/$POSTGRES_VERSION/ssl"]

CMD /scripts/db_start.sh