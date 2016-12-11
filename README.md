Postgres 9.6 with PostGIS 2.3, SFCGAL, Topology, Tiger Geocoder, pgrouting, raster, and SSL support.

Volume Mapping the data path
----------------------------
- This container maps the `/postgresql/9.6/main` volume path. If you do not map a local directory path to this volume, then it will create a new database setup inside the container. This data WILL NOT persist if you delete the container.

- If you map the volume `/postgresql/9.6/main` to a local directory path, and if this directory is empty, then a new database will be initialised in this location.

- If this locally mapped directory is not empty, then the container will try to reuse an existing database if present inside this directory. If it is not able to do so, or if the folder contains other files or folders, then you will encounter an error.

Environment Variables
---------------------
The following environment variables can be set for configuring a new database.

Environment Variable | Default | Description
------------------------|---------|--------------
`PG_USER` |  `my_username` | The username for your database role (user).
`PG_PASSWORD` | `my_password` | Your password.
`DB_NAME` | `my_db` | The name for the new database.

Port Mapping
------------
You will not be able to connect to your database at `localhost:5432` unless you first map the docker container's exposed `5432` port to your local `5432` port.

Gotchas
-------
If you first upload data to your container (before providing a mapped volume to your local machine), and then subsequently provide a mapped volume, then the mapped volume will be mapped over the internal folder and you will not be able to see data you may have previously uploaded into the container until you run it again without a volume mapping.

Example
-------
For running the database in the foreground:
```
docker run -p 5432:5432  \
    -e "PG_USER=my_username" \
    -e "PG_PASSWORD=my_password" \
    -e "DB_NAME=my_db" \
    --restart=unless-stopped \
    --volume=/path/to/local/folder:/postgresql/9.6/main \
    shongololo/postgis
docker logs -f <docker image id>
```

Or if running detached, use the -d flag instead of -i and -t.

If you are running the container using an existing folder that already contains a configured database, then you can omit the environment flags. If you omit the environment arguments and a database has not already been initialised, then the default values will be used.

Using with SSL
--------------

To use SSL, prepare a `server.crt` (certificate file) and `server.key` (key file) and place these in a folder.
Then map the folder to the container's `/postgresql/9.6/ssl/` path by passing an additional volume flag, i.e.:

```
docker run -p 5432:5432  \
    -e "PG_USER=my_username" \
    -e "PG_PASSWORD=my_password" \
    -e "DB_NAME=my_db" \
    --restart=unless-stopped \
    --volume=/path/to/local/folder:/postgresql/9.6/main \
    --volume=/path/to/local/ssl/files:/postgresql/9.6/ssl` \
    shongololo/postgis
docker logs -f <docker image id>
```


> Provided you have a domain name mapped to your postgres server, then you can prepare a certificate and key file by using the free lets-enccrypt service.
> For example:
> ```bash
> # install acme.sh
> sudo apt-get install wget cron netcat
> wget -O - https://get.acme.sh | sh
>
> # generate the certificate for your domain
> sudo ~/.acme.sh/acme.sh --issue --standalone -d my_domain.com
>
> # install the certificate and key file to your folder path
> mkdir /path/to/local/ssl/files
> ~/.acme.sh/acme.sh --installcert -d my_domain.com \
>     --certpath    /path/to/local/ssl/files/server.crt \
>     --keypath     /path/to/local/ssl/files/server.key
> sudo chmod 0600 /path/to/local/ssl/files/server.key
> ```

Configuration Parameters
------------------------
The default configured settings are based on 4GB of RAM and a maximum 20 connections. The tuning parameters are set in accordance with [http://pgtune.leopard.in.ua](pgtune). You can edit the `postgresql.conf ` file inside your mapped data path directory for further customisation. These will have been appended to the end of the file and should be modified there.

>max_connections = 20  
>shared_buffers = 1GB  
>effective_cache_size = 3GB  
>work_mem = 26214kB  
>maintenance_work_mem = 256MB  
>min_wal_size = 1GB  
>max_wal_size = 2GB  
>checkpoint_completion_target = 0.9  
>wal_buffers = 16MB  
>default_statistics_target = 100  
