FROM ubuntu:16.04

MAINTAINER garethsimons@me.com

RUN locale-gen en_GB.UTF-8
RUN update-locale LANG=en_GB.UTF-8

RUN apt-get update && apt-get install -y \
    build-essential cmake libboost-dev libboost-system-dev libboost-filesystem-dev libgeos-dev \
    libgeos++-dev libexpat1-dev zlib1g-dev libbz2-dev libpq-dev libproj-dev lua5.2 liblua5.2-dev \
    software-properties-common wget

RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt xenial-pgdg main" >> /etc/apt/sources.list'
RUN wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
RUN apt-get update && apt-get install -y \
    postgresql-9.6 pgadmin3 postgresql-contrib-9.6 \
    postgresql-9.6-postgis-2.3 postgresql-9.6-postgis-2.3-scripts \
    postgresql-9.6-pgrouting postgresql-9.6-pgrouting-doc \
    gdal-bin

ADD scripts /scripts
RUN chmod -R 0755 /scripts

# create the directory and set permissions prior to mapping the volume
RUN mkdir -p /postgresql/9.6/main
RUN chown -R postgres:postgres /postgresql/9.6/main
RUN chmod -R 0700 /postgresql/9.6/main

EXPOSE 5432

VOLUME  /postgresql/9.6/main

USER postgres

CMD /scripts/db_start.sh