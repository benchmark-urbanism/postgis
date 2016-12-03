FROM ubuntu:16.04

MAINTAINER garethsimons@me.com

RUN locale-gen en_GB.UTF-8
RUN update-locale LANG=en_GB.UTF-8

RUN apt-get update && apt-get install -y wget cron netcat

# install Postgres etc.
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt xenial-pgdg main" >> /etc/apt/sources.list'
RUN wget --quiet -O - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add -
RUN apt-get update && apt-get install -y gdal-bin postgresql-9.6 postgresql-contrib-9.6 postgresql-9.6-postgis-2.3 \
        postgresql-9.6-postgis-2.3-scripts postgresql-9.6-pgrouting

# install acme.sh for setting up lets encrypt certs
RUN wget -O -  https://get.acme.sh | sh

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