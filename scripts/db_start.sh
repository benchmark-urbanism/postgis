#!/usr/bin/env bash

# use /etc/postgresql/9.6/main for the 'data directory'. When the database starts it will load postgresql.conf from
# this location, which, in turn, points to /var/lib/postgresql/9.6/main (the mapped directory) as the actual data location.
# The intent is to keep the postgresql.conf settings separate from the database data to simplify modifications via docker.

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
      printf "NOTE -> Using default PG_USER value: $PG_USER "
    else
      printf "NOTE -> Using supplied PG_USER value: $PG_USER "
    fi

    if [ -z "$PG_PASSWORD" ]; then
      export PG_PASSWORD=my_password
      printf "NOTE -> Using default PG_PASSWORD value: $PG_PASSWORD "
    else
      printf "NOTE -> Using supplied PG_PASSWORD value: $PG_PASSWORD "
    fi

    if [ -z "$DB_NAME" ]; then
      export DB_NAME=my_db
      printf "NOTE -> Using default DB_NAME value: $DB_NAME "
    else
      printf "NOTE -> Using supplied DB_NAME value: $DB_NAME "
    fi
    
    if [ -z "$LETSENCRYPT_DOMAIN" ]; then
      printf "NOTE -> No domain name provided -> not enabling SSL "
    else
      printf "NOTE -> Domain name and email address provided, emabling SSL, this will only work if port 80 is open "
      /root/.acme.sh/acme.sh --issue --standalone -d $LETSENCRYPT_DOMAIN
      /root/.acme.sh/acme.sh --installcert -d $LETSENCRYPT_DOMAIN \
        --certpath /postgresql/9.6/main/server.crt \
        --keypath /postgresql/9.6/main/server.key
    fi

    /usr/lib/postgresql/9.6/bin/pg_ctl initdb -D /postgresql/9.6/main -o '--locale=en_GB.utf-8'

    /usr/lib/postgresql/9.6/bin/pg_ctl start -w -D /postgresql/9.6/main

    # setup basic database and permissions
    psql -v ON_ERROR_STOP=1 -c "ALTER USER postgres WITH PASSWORD '$PG_PASSWORD';"
    psql -v ON_ERROR_STOP=1 -c "CREATE ROLE $PG_USER LOGIN PASSWORD '$PG_PASSWORD';"
    psql -v ON_ERROR_STOP=1 -c "CREATE DATABASE $DB_NAME OWNER $PG_USER;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION adminpack;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION hstore;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION postgis;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION postgis_topology;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION postgis_sfcgal;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION fuzzystrmatch;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION address_standardizer;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION postgis_tiger_geocoder;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "CREATE EXTENSION pgrouting;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "SET postgis.gdal_enabled_drivers TO ENABLE_ALL;"
    psql -v ON_ERROR_STOP=1 -d $DB_NAME -c "SET postgis.enable_outdb_rasters TO True;"

    # setup pg_hba.conf
    if [ -z "$LETSENCRYPT_DOMAIN" ]; then
      echo "host      all     all     0.0.0.0/0   md5" >> /postgresql/9.6/main/pg_hba.conf
    else
      echo "hostssl      all     all     0.0.0.0/0   md5" >> /postgresql/9.6/main/pg_hba.conf
      echo "ssl = on" >> /postgresql/9.6/main/postgresql.conf
    fi

    # setup configs
    echo "listen_addresses='*'" >> /postgresql/9.6/main/postgresql.conf

    # SEE http://pgtune.leopard.in.ua -> presently based on 4GB mixed purpose at 20 max connections

    echo 'max_connections = 20' >> /postgresql/9.6/main/postgresql.conf
    # some say to set shared_buffers to a 1/4 of your memory
    echo 'shared_buffers = 1GB' >> /postgresql/9.6/main/postgresql.conf
    echo 'effective_cache_size = 3GB' >> /postgresql/9.6/main/postgresql.conf
    # work_mem is used per table per user, e.g. 4 tables * 5 users * 100 = 2000 * parallel workers...
    echo 'work_mem=26214kB' >> /postgresql/9.6/main/postgresql.conf
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

    /usr/lib/postgresql/9.6/bin/pg_ctl stop -D /postgresql/9.6/main -m smart
    /usr/lib/postgresql/9.6/bin/postgres -D /postgresql/9.6/main

else

    echo "Existing database installation found. Starting existing database."
    echo "Map an empty folder if you wish to create a new database instead."

    # set starting database configuration parameters
    export POSTGIS_ENABLE_OUTDB_RASTERS=1
    export POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL

    /usr/lib/postgresql/9.6/bin/postgres -D /postgresql/9.6/main

fi
