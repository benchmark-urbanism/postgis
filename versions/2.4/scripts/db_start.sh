#!/usr/bin/env bash

set -e # exit if non-zero
set -o # exit if pipefail

export PG_VERSION=10

# check if a PG_VERSION file exists in the data directory
if [ ! -f /postgresql/$PG_VERSION/main/postgresql.conf ]
then
    # if not, initialise new db
    echo "No postgres config file found in folder. Attempting to create database."

    echo "Present data path directory contents. Note that if this folder is not empty, then an error will be returned."
    ls /postgresql/$PG_VERSION/main

    echo "Setting permissions on folders"
    chown -R postgres:postgres /postgresql/$PG_VERSION/main
    chmod 0600 /postgresql/$PG_VERSION/main
    gosu postgres /usr/lib/postgresql/$PG_VERSION/bin/pg_ctl initdb -D /postgresql/$PG_VERSION/main -o '--locale=en_GB.UTF-8'
    gosu postgres /usr/lib/postgresql/$PG_VERSION/bin/pg_ctl start -w -D /postgresql/$PG_VERSION/main

    # check whether POSTGRES_USER, POSTGRES_PASS, and DB_NAME have been supplied via environment variables. If not, use defaults.
    if [ -z "$PG_USER" ]; then
      export PG_USER=my_username
      printf "NOTE -> Using default PG_USER value: $PG_USER\n"
    else
      printf "NOTE -> Using supplied PG_USER value: $PG_USER\n"
    fi

    if [ -z "$DB_NAME" ]; then
      export DB_NAME=my_db
      printf "NOTE -> Using default DB_NAME value: $DB_NAME\n"
    else
      printf "NOTE -> Using supplied DB_NAME value: $DB_NAME\n"
    fi

    # setup configs and create user
    echo "local     all     all                 trust" >> /postgresql/$PG_VERSION/main/pg_hba.conf
    echo "listen_addresses='*'" >> /postgresql/$PG_VERSION/main/postgresql.conf

    # use no password by default
    if [ -z "$PG_PASSWORD" ]; then
      printf "NOTE -> No PG_PASSWORD value supplied, no password will be set for 'postgres' and '$PG_USER' users\n"
      # setup pg_hba permissions
      echo "host      all     all     0.0.0.0/0   trust" >> /postgresql/$PG_VERSION/main/pg_hba.conf
      # setup basic database and permissions
      gosu postgres psql -v ON_ERROR_STOP=1 << EOF
          CREATE ROLE $PG_USER LOGIN;
          CREATE DATABASE $DB_NAME OWNER $PG_USER;
EOF
    else
      printf "NOTE -> Using supplied PG_PASSWORD value: $PG_PASSWORD for 'postgres' and '$PG_USER' users\n"
      # setup pg_hba permissions
      echo "host      all     all     0.0.0.0/0   md5" >> /postgresql/$PG_VERSION/main/pg_hba.conf
      # setup basic database and permissions
      gosu postgres psql -v ON_ERROR_STOP=1 << EOF
          ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';
          CREATE ROLE $PG_USER LOGIN PASSWORD '$PG_PASSWORD';
          CREATE DATABASE $DB_NAME OWNER $PG_USER;
EOF
    fi

    # allow the new user to SET ROLE to postgres user for future admin tasks
    # and setup general purpose extensions
    gosu postgres psql -v ON_ERROR_STOP=1 --dbname=$DB_NAME << EOF
        GRANT postgres TO $PG_USER;
        CREATE EXTENSION adminpack;
        CREATE EXTENSION pg_trgm;
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

    # add SSL if certificate and key files provided
    if [ ! -f postgresql/$PG_VERSION/ssl/server.crt ]; then
      printf "NOTE -> No certificate file provided -> not enabling SSL\n"
      echo "ssl = off" >> /postgresql/$PG_VERSION/main/postgresql.conf
    else
        if [ ! -f postgresql/$PG_VERSION/ssl/server.key ]; then
            printf "NOTE -> No key file provided -> not enabling SSL\n"
            echo "ssl = off" >> /postgresql/$PG_VERSION/main/postgresql.conf
        else
            printf "NOTE -> found server certificate and key -> enabling SSL\n"
            echo "ssl = on" >> /postgresql/$PG_VERSION/main/postgresql.conf
            echo "ssl_cert_file = '/postgresql/$PG_VERSION/ssl/server.crt'" >> /postgresql/$PG_VERSION/main/postgresql.conf
            chown postgres:postgres /postgresql/$PG_VERSION/ssl/server.key
            chmod 0600 /postgresql/$PG_VERSION/ssl/server.key
            echo "ssl_key_file = '/postgresql/$PG_VERSION/ssl/server.key'" >> /postgresql/$PG_VERSION/main/postgresql.conf
        fi
    fi

    # SEE http://pgtune.leopard.in.ua -> presently based on 4GB, 4CPU, HDD, mixed purpose at 50 max connections
    gosu postgres psql -v ON_ERROR_STOP=1 << EOF
        ALTER SYSTEM SET max_connections = '50';
        ALTER SYSTEM SET shared_buffers = '1GB';
        ALTER SYSTEM SET effective_cache_size = '3GB';
        ALTER SYSTEM SET work_mem = '10485kB';
        ALTER SYSTEM SET maintenance_work_mem = '256MB';
        ALTER SYSTEM SET min_wal_size = '1GB';
        ALTER SYSTEM SET max_wal_size = '2GB';
        ALTER SYSTEM SET checkpoint_completion_target = '0.9';
        ALTER SYSTEM SET wal_buffers = '16MB';
        ALTER SYSTEM SET default_statistics_target = '100';
        ALTER SYSTEM SET random_page_cost = '4';
        ALTER SYSTEM SET effective_io_concurrency = '2';
        ALTER SYSTEM SET max_worker_processes = '4';
        ALTER SYSTEM SET max_parallel_workers_per_gather = '2';
        ALTER SYSTEM SET max_parallel_workers = '4';
EOF
    echo "Database setup completed. Restarting server in foreground:"

    gosu postgres /usr/lib/postgresql/$PG_VERSION/bin/pg_ctl stop -D /postgresql/$PG_VERSION/main -m smart
    gosu postgres /usr/lib/postgresql/$PG_VERSION/bin/postgres -D /postgresql/$PG_VERSION/main

else

    echo "Existing database installation found. Starting existing database."
    echo "Map an empty folder if you wish to create a new database instead."

    # set starting database configuration parameters
    export POSTGIS_ENABLE_OUTDB_RASTERS=1
    export POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL

    # verify permissions on existing folders
    chown -R postgres:postgres /postgresql/$PG_VERSION/main
    chmod 0700 /postgresql/$PG_VERSION/main

    if [ ! -f postgresql/$PG_VERSION/ssl/server.crt ]; then
          printf "NOTE -> No certificate file provided -> disabling SSL if present\n"
          export PGSSLMODE=disable
    else
        if [ ! -f postgresql/$PG_VERSION/ssl/server.key ]; then
            printf "NOTE -> No key file provided -> disabling SSL if present\n"
            export PGSSLMODE=disable
        else
            printf "NOTE -> found server certificate and key -> enabling SSL\n"
            printf "HOWEVER... SSL will only work if DB initialised with SSL\n"
            printf "OTHERWISE -> manually edit your postgresql.conf and set ssl = on\n"
            sed "s/ssl = off/ssl = on/" /postgresql/$PG_VERSION/main/postgresql.conf
            export PGSSLMODE=require
        fi
    fi

    gosu postgres /usr/lib/postgresql/$PG_VERSION/bin/postgres -D /postgresql/$PG_VERSION/main

fi
