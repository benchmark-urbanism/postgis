Postgres 11 with PostGIS 2.5, SFCGAL, and pgrouting 2.6.1, plus raster and SSL support.

[![](https://images.microbadger.com/badges/image/cityseer/postgis.svg)](https://microbadger.com/images/cityseer/postgis "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/cityseer/postgis.svg)](https://microbadger.com/images/cityseer/postgis "Get your own version badge on microbadger.com")

Docker Hub Repo
---------------

[cityseer/postgis](https://hub.docker.com/r/cityseer/postgis/)

Docker Hub Tag
--------------

`cityseer/postgis`

Versions
--------

- `latest`: Postgres 11 + PostGIS 2.5.1 (Geos 3.7.1), SFCGAL 1.3.6 (CGAL 4.13), pgrouting 2.6.2
- `2.5`: Postgres 11 + PostGIS 2.5.1 (Geos 3.7.1), SFCGAL 1.3.6 (CGAL 4.13), pgrouting 2.6.2
- `2.5_10`: Postgres 11 + PostGIS 2.5.1 (Geos 3.7.1), SFCGAL 1.3.6 (CGAL 4.13), pgrouting 2.6.2
- `2.4`: Postgres 10 + PostGIS 2.4.5 (Geos 3.6.3), SFCGAL 1.3.6 (CGAL 4.11.3), pgrouting 2.6.1
- `2.3`: Postgres 9.6 + PostGIS 2.3.7 (Geos 3.6.3), SFCGAL 1.3.6 (CGAL 4.11.3), pgrouting 2.6.1

Mapping the data volume path
----------------------------
- This container maps the `/postgresql/11/main` volume path. If you do not map a local directory path to this volume, then it will create a new database setup inside the container. This data WILL NOT persist if you delete the container.

- If you map the volume `/postgresql/11/main` to a local directory path, and if this directory is empty, then a new database will be initialised in this location.

- If this locally mapped directory is not empty, then the container will try to reuse an existing database if present inside this directory. If it is not able to do so, or if the folder contains other files or folders, then you will encounter an error.

> For tags `2.5_10`, `2.4` or `2.3`, use the corresponding postgres version numbers, e.g. `/postgresql/10/main` or `/postgresql/9.6/main`, respectively.

Environment variables
---------------------
The following environment variables can be set for configuring a new database.

Environment Variable | Default | Description
------------------------|---------|--------------
`PG_USER` |  `my_username` | The username for your database role (user).
`PG_PASSWORD` | none | Optional password.
`DB_NAME` | `my_db` | The name for the new database.

The new user will have general permissions on the new database. The user is also granted membership to the `postgres` super-user. This means that `SET ROLE postgres;` can be used to grant temporary permissions for superuser tasks such as activating extensions. Once admin tasks are completed, user permissions can be reset per `RESET ROLE;`

If you initialise the database without a password and then add a password at a later stage, then you'll likely also want to modify the `pg_hba.conf` file in your mapped data directory to require md5 password authentication for connections. For example, you may want to change this line:  
`host    all             all             0.0.0.0/0               trust`  
to:  
`host    all             all             0.0.0.0/0               md5`  

Port Mapping
------------
You will not be able to connect to your database at `localhost:5432` unless you first map the docker container's exposed `5432` port to your local `5432` port.

Gotchas
-------
If you first upload data to your container (before providing a mapped volume to your local machine), and then subsequently provide a mapped volume, then the mapped volume will be mapped over the internal folder and you will not be able to see data you may have previously uploaded into the container until you run it again without a volume mapping.

Example
-------
For running the database detached:
```bash
docker run -d -p 5432:5432  \
    -e "PG_USER=my_username" \
    -e "PG_PASSWORD=my_password" \
    -e "DB_NAME=my_db" \
    --restart=unless-stopped \
    --volume=/path/to/data:/postgresql/11/main \
    cityseer/postgis:latest
```
You can then follow the logs:
```bash
docker logs -f <docker image id>
```

If you are running the container using an existing folder that already contains a configured database, then you can omit the environment flags. Note that if you omit the environment arguments when initialising a new database, then the default values will be used.

Using with SSL
--------------

To use SSL, prepare a `server.crt` (certificate file) and `server.key` (key file) and place these in a folder.
Then map the folder to the container's `/postgresql/11/ssl/` path by passing an additional volume flag, i.e.:

```
docker run -d -p 5432:5432  \
    -e "PG_USER=my_username" \
    -e "PG_PASSWORD=my_password" \
    -e "DB_NAME=my_db" \
    --restart=unless-stopped \
    --volume=/path/to/data:/postgresql/11/main \
    --volume=/path/to/ssl:/postgresql/11/ssl` \
    cityseer/postgis:latest
```
You can then follow the logs:
```bash
docker logs -f <docker image id>
```

> Provided you have a domain name mapped to your postgres server, then you can prepare a certificate and key file by using the free lets-encrypt service.
> For example:
> ```bash
> # install acme.sh
> sudo apt-get install wget cron netcat
> wget -O - https://get.acme.sh | sh
>
> # generate the certificate for your domain
> sudo ~/.acme.sh/acme.sh --issue --standalone -d your_domain.com
>
> # install the certificate and key file to your folder path
> mkdir /path/to/local/ssl/files
> ~/.acme.sh/acme.sh --installcert -d my_domain.com \
>     --certpath    /path/to/ssl/server.crt \
>     --keypath     /path/to/ssl/server.key
> sudo chmod 0600 /path/to/ssl/server.key
> ```

Configuration Parameters
------------------------
The tuning parameters are set in accordance with [http://pgtune.leopard.in.ua](pgtune).

> Assumed parameters:  
  DB Version: 11  
  OS Type: linux  
  DB Type: mixed  
  Total Memory (RAM): 4 GB  
  Number of Connections: 50
  Data Storage: HDD

The parameters are modified using the `ALTER SYSTEM` command which writes the custom configuration settings to the `postgresql.auto.conf` file, which overrides the default settings in `postgresql.conf`. This file should not be modified manually.

Configuration:
- max_connections = 50
- shared_buffers = 1GB
- effective_cache_size = 3GB
- maintenance_work_mem = 256MB
- checkpoint_completion_target = 0.9
- wal_buffers = 16MB
- default_statistics_target = 100
- random_page_cost = 4
- effective_io_concurrency = 2
- work_mem = 10485kB
- min_wal_size = 1GB
- max_wal_size = 2GB

It is worth considering updating these parameters if you are using an SSD drive or large amounts of RAM. For customisation, connect as the `postgres` superuser then use the [`ALTER SYSTEM`](https://www.postgresql.org/docs/10/static/sql-altersystem.html) command to update the desired configuration settings, then restart the database, for example:
```postgresql
SET ROLE postgres;
ALTER SYSTEM SET max_connections = '100';
RESET ROLE;
SELECT pg_reload_conf();
```
