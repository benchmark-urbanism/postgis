#!/usr/bin/env bash

set -e # exit if non-zero
set -o # exit if pipefail

# check if a PG_VERSION file exists in the data directory
if [ ! -f /postgresql/9.6/main/postgresql.conf ]
then
    # if not, initialise new db
    echo "No postgres config file found in folder. Attempting to create database."

    echo "Present data path directory contents. Note that if this folder is not empty, then an error will be returned."
    ls /postgresql/9.6/main

    # check whether POSTGRES_USER, POSTGRES_PASS, and DB_NAME have been supplied via environment variables. If not, use defaults.
    if [ -z "$PG_USER" ]; then
      export PG_USER=my_username
      printf "\nNOTE -> Using default PG_USER value: $PG_USER\n"
    else
      printf "\nNOTE -> Using supplied PG_USER value: $PG_USER\n"
    fi

    if [ -z "$PG_PASSWORD" ]; then
      export PG_PASSWORD=my_password
      printf "\nNOTE -> Using default PG_PASSWORD value: $PG_PASSWORD\n"
    else
      printf "\nNOTE -> Using supplied PG_PASSWORD value: $PG_PASSWORD\n"
    fi

    if [ -z "$DB_NAME" ]; then
      export DB_NAME=my_db
      printf "\nNOTE -> Using default DB_NAME value: $DB_NAME\n"
    else
      printf "\nNOTE -> Using supplied DB_NAME value: $DB_NAME\n"
    fi

    chown -R postgres:postgres /postgresql/9.6/main
    chmod 0600 /postgresql/9.6/main
    gosu postgres /usr/lib/postgresql/9.6/bin/pg_ctl initdb -D /postgresql/9.6/main -o '--locale=en_GB.UTF-8'
    gosu postgres /usr/lib/postgresql/9.6/bin/pg_ctl start -w -D /postgresql/9.6/main

    # setup basic database and permissions
    gosu postgres psql -v ON_ERROR_STOP=1 << EOF
        ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';
        CREATE ROLE $PG_USER LOGIN PASSWORD '$PG_PASSWORD';
        CREATE DATABASE $DB_NAME OWNER $PG_USER;
EOF

    gosu postgres psql -v ON_ERROR_STOP=1 --dbname=$DB_NAME << EOF
        CREATE EXTENSION adminpack;
        CREATE EXTENSION hstore;
        CREATE EXTENSION postgis;
        CREATE EXTENSION postgis_topology;
        CREATE EXTENSION postgis_sfcgal;
        CREATE EXTENSION fuzzystrmatch;
        CREATE EXTENSION address_standardizer;
        CREATE EXTENSION postgis_tiger_geocoder;
        CREATE EXTENSION pgrouting;
        SET postgis.gdal_enabled_drivers = 'ENABLE_ALL';
        SET postgis.enable_outdb_rasters = True;
EOF

    # setup configs
    echo "host      all     all     0.0.0.0/0   md5" >> /postgresql/9.6/main/pg_hba.conf
    echo "listen_addresses='*'" >> /postgresql/9.6/main/postgresql.conf

    # add SSL if certificate and key files provided
    if [ ! -f postgresql/9.6/ssl/server.crt ]; then
      printf "\nNOTE -> No certificate file provided -> not enabling SSL\n"
      echo "ssl = off" >> /postgresql/9.6/main/postgresql.conf
    else
        if [ ! -f postgresql/9.6/ssl/server.key ]; then
            printf "\nNOTE -> No key file provided -> not enabling SSL\n"
            echo "ssl = off" >> /postgresql/9.6/main/postgresql.conf
        else
            printf "\nNOTE -> found server certificate and key -> enabling SSL\n"
            echo "ssl = on" >> /postgresql/9.6/main/postgresql.conf
            echo "ssl_cert_file = '/postgresql/9.6/ssl/server.crt'" >> /postgresql/9.6/main/postgresql.conf
            chown postgres:postgres /postgresql/9.6/ssl/server.key
            chmod 0600 /postgresql/9.6/ssl/server.key
            echo "ssl_key_file = '/postgresql/9.6/ssl/server.key'" >> /postgresql/9.6/main/postgresql.conf
        fi
    fi

    # SEE http://pgtune.leopard.in.ua -> presently based on 4GB mixed purpose at 50 max connections

    echo 'max_connections = 50' >> /postgresql/9.6/main/postgresql.conf
    # some say to set shared_buffers to a 1/4 of your memory
    echo 'shared_buffers = 1GB' >> /postgresql/9.6/main/postgresql.conf
    echo 'effective_cache_size = 3GB' >> /postgresql/9.6/main/postgresql.conf
    # work_mem is used per table per user, e.g. 4 tables * 5 users * 100 = 2000 * parallel workers...
    echo 'work_mem=10485kB' >> /postgresql/9.6/main/postgresql.conf
    # typically only one of these at a time, so it is safe to use larger values
    echo 'maintenance_work_mem = 256MB' >> /postgresql/9.6/main/postgresql.conf
    echo 'min_wal_size = 1GB' >> /postgresql/9.6/main/postgresql.conf
    echo 'max_wal_size = 2GB' >> /postgresql/9.6/main/postgresql.conf
    echo 'checkpoint_completion_target = 0.9' >> /postgresql/9.6/main/postgresql.conf
    echo 'wal_buffers = 16MB' >> /postgresql/9.6/main/postgresql.conf
    echo 'default_statistics_target = 100' >> /postgresql/9.6/main/postgresql.conf
    # effective_io_concurrency -> for SSDs set higher
    echo 'effective_io_concurrency=2' >> /postgresql/9.6/main/postgresql.conf
    # max_worker_processes -> default is 8
    echo 'max_worker_processes=8' >> /postgresql/9.6/main/postgresql.conf
    # max_parallel_workers_per_gather -> these workers are taken from the max_worker_processes
    echo 'max_parallel_workers_per_gather=4' >> /postgresql/9.6/main/postgresql.conf

    echo "Database setup completed. Restarting server in foreground:"

    gosu postgres /usr/lib/postgresql/9.6/bin/pg_ctl stop -D /postgresql/9.6/main -m smart
    gosu postgres /usr/lib/postgresql/9.6/bin/postgres -D /postgresql/9.6/main

else

    echo "Existing database installation found. Starting existing database."
    echo "Map an empty folder if you wish to create a new database instead."

    # set starting database configuration parameters
    export POSTGIS_ENABLE_OUTDB_RASTERS=1
    export POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL

    if [ ! -f postgresql/9.6/ssl/server.crt ]; then
          printf "\nNOTE -> No certificate file provided -> disabling SSL if present\n"
          export PGSSLMODE=disable
    else
        if [ ! -f postgresql/9.6/ssl/server.key ]; then
            printf "\nNOTE -> No key file provided -> disabling SSL if present\n"
            export PGSSLMODE=disable
        else
            printf "\nNOTE -> found server certificate and key -> enabling SSL\n"
            printf "\nHOWEVER... SSL will only work if DB initialised with SSL\n"
            printf "\nOTHERWISE -> manually edit your postgresql.conf and set ssl = on\n"
            sed "s/ssl = off/ssl = on/" /postgresql/9.6/main/postgresql.conf
            export PGSSLMODE=require
        fi
    fi

    gosu postgres /usr/lib/postgresql/9.6/bin/postgres -D /postgresql/9.6/main

fi
