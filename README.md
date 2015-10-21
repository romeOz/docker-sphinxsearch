Table of Contents
-------------------

 * [Installation](#installation)
 * [Quick Start](#quick-start)
 * [Example](#example)
  - [Only Sphinx](#only-sphinx)
  - [Sphinx + MySQL Client (usage PostgreSQL or other source type)](#sphinx--mysql-client)
 * [Persistence](#persistence)
 * [Backup of a indexes](#backup-of-a-indexes)
 * [Checking backup](#checking-backup)
 * [Restore from backup](#restore-from-backup)
 * [Environment variables](#environment-variables)
 * [Logging](#logging) 
 * [Out of the box](#out-of-the-box)
 
Installation
-------------------

 * [Install Docker](https://docs.docker.com/installation/) or [askubuntu](http://askubuntu.com/a/473720)
 * Pull the latest version of the image.
 
```bash
docker pull romeoz/docker-sphinxsearch
```

or extended (for using PostgreSQL or other source type):

```bash
docker pull romeoz/docker-sphinxsearch:ext
```

Alternately you can build the image yourself.

```bash
git clone https://github.com/romeoz/docker-sphinxsearch.git
cd docker-sphinxsearch
docker build -t="$USER/sphinxsearch" .
```

Quick Start
-------------------

Use one of two ways:

1) Use Docker Compose
 
```bash  
curl -L https://github.com/romeoz/docker-sphinxsearch/raw/master/docker-compose.yml > docker-compose.yml
docker-compose up -d
``` 
2) Step by step.

Run the mysql image:

```bash
docker run --name db -d \
  -e 'MYSQL_USER=test' -e 'MYSQL_PASS=pass' -e 'MYSQL_CACHE_ENABLED=true' \
  romeoz/docker-mysql
```

>Recommended way (official). Sphinx own implementation of MySQL network protocol (using a small SQL subset called SphinxQL).

Run the sphinx image:

```bash
docker run --name sphinx -d \
  --link db:db \
  romeoz/docker-sphinxsearch
```

Example
-------------------

####Only Sphinx

Run the mysql image with with the creation of database `db_test`:

```bash
docker run --name db -d \
  -e 'MYSQL_USER=test' -e 'MYSQL_PASS=pass' -e 'MYSQL_CACHE_ENABLED=true' \
  -e 'DB_NAME=db_test' \
  romeoz/docker-mysql
```

Creating table `items` and records:

```bash
docker exec -it db \
  mysql -uroot -e 'CREATE TABLE db_test.items (id INT NOT NULL AUTO_INCREMENT, content TEXT, PRIMARY KEY(id)) ENGINE = INNODB;'
  
docker exec -it db \
  mysql -uroot -e 'INSERT INTO db_test.items (content) VALUES ("about dog"),("about cat");'
```

Run the sphinx image:

```bash
docker run --name sphinx -d \
  --link db:db \
  romeoz/docker-sphinxsearch
```

Indexing database:

```bash
docker exec -it sphinx \
  indexer --config /etc/sphinxsearch/sphinx.conf --all --rotate
```

Searching records:

```bash
host=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' sphinx);
docker exec -it db \
  mysql -P9306 -h${host} -e "SELECT * FROM items_index WHERE MATCH('cat');"
```

####Sphinx + MySQL Client

You can using other source type, for example PostgreSQL. If you want to use the SphinxQL, there is no need to install the MySQL server.
It helps to have the `mysql-common` package and `mysql-client` (if you need a CLI). Container Sphinx + MySQL client built specifically for this.

Run the postgresql image with with the creation of database `db_test`:

```bash
docker run --name db-test -d \
  -e 'DB_NAME=db_test' -e 'DB_USER=tom' -e 'DB_PASS=pass' \
  romeoz/docker-postgresql
```

Creating table `items` and records:

```bash
docker exec -it db-test sudo -u postgres psql db_test \
  -c "CREATE TABLE items (id SERIAL, content TEXT);"
docker exec -it db-test sudo -u postgres psql db_test \
  -c "GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO tom; GRANT SELECT ON ALL TABLES IN SCHEMA public TO tom;"
docker exec -it db-test sudo -u postgres psql db_test \
  -c "INSERT INTO items (content) VALUES ('about dog'),('about cat');"
```

Run the extended sphinx image:

```bash
docker run --name sphinx-ext -d \
  --link db:db \
  romeoz/docker-sphinxsearch:ext
```

Indexing database:

```bash
docker exec -it sphinx-ext \
  indexer --config /etc/sphinxsearch/sphinx.conf --all --rotate
```

Searching records:

```bash
docker exec -it sphinx-ext \
  mysql -P9306 -h127.0.0.1 -e "SELECT * FROM items_index WHERE MATCH('cat');"
```

Persistence
-------------------

For data persistence a volume should be mounted at `/var/lib/sphinxsearch/data`.

The updated run command looks like this.

```bash
docker run --name sphinx -d \
  -v /host/to/path/data:/var/lib/sphinxsearch/data \
  romeoz/docker-sphinxsearch
```

This will make sure that the data stored in the index is not lost when the image is stopped and started again.


Backup of a indexes
-------------------

If you are using RT index, then first we need to flush indexes `FLUSH RTINDEX`:

```bash
host=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' sphinx)
docker exec -it db mysql -P9306 -h${host} -e "FLUSH RTINDEX some_rtindex"
```

Next, create a temporary container for backup:

```bash
docker run -it --rm \ 
  --volumes-from sphinx \
  -e 'SPHINX_MODE=backup' \
  -v /host/to/path/backup:/tmp/backup \
  romeoz/docker-sphinxsearch
```  
Archive will be available in the `/host/to/path/backup`.

> Algorithm: one backup per week (total 4), one backup per month (total 12) and the last backup. Example: `backup.last.tar.gz`, `backup.1.tar.gz` and `/backup.dec.tar.gz`.

You can disable the rotation by using env `SPHINX_ROTATE_BACKUP=false`.

Checking backup
-------------------

Check-data is the name of index `INDEX_NAME`. 

```bash
docker run -it --rm \  
  -e 'SPHINX_CHECK=default' -e 'INDEX_NAME=items_index' \
  -v /host/to/path/backup:/tmp/backup  \
  romeoz/docker-sphinxsearch
```

Default used the `/tmp/backup/backup.last.tar.gz`.

Restore from backup
-------------------

```bash
docker run --name sphinx-restore -d \
  --link db:db \
  -e 'SPHINX_RESTORE=default' \
  -v /host/to/path/backup:/tmp/backup  \
  romeoz/docker-sphinxsearch
```

Environment variables
---------------------

`SPHINX_MODE`: Set a specific mode. Takes on the value `backup`.

`SPHINX_BACKUP_DIR`: Set a specific backup directory (default "/tmp/backup").

`SPHINX_BACKUP_FILENAME`: Set a specific filename backup (default "backup.last.tar.gz").

`SPHINX_CHECK`: Defines name of backup to `indextool --check`. Note that the backup must be inside the container, so you may need to mount them. You can specify as `default` that is equivalent to the `/tmp/backup/backup.tar.gz`

`SPHINX_RESTORE`: Defines name of backup to initialize the demon `searchd`. Note that the backup must be inside the container, so you may need to mount them. You can specify as `default` that is equivalent to the `/tmp/backup/backup.last.tar.gz`

`SPHINX_ROTATE_BACKUP`: Determines whether to use the rotation of backups (default "true").

Logging
-------------------

All the logs are forwarded to stdout and sterr. You have use the command `docker logs`.

```bash
docker logs sphinx
```

####Split the logs

You can then simply split the stdout & stderr of the container by piping the separate streams and send them to files:

```bash
docker logs sphinx > stdout.log 2>stderr.log
cat stdout.log
cat stderr.log
```

or split stdout and error to host stdout:

```bash
docker logs sphinx > -
docker logs sphinx 2> -
```

####Rotate logs

Create the file `/etc/logrotate.d/docker-containers` with the following text inside:

```
/var/lib/docker/containers/*/*.log {
    rotate 31
    daily
    nocompress
    missingok
    notifempty
    copytruncate
}
```
> Optionally, you can replace `nocompress` to `compress` and change the number of days.

Out of the box
-------------------
 * Ubuntu 14.04.3 (LTS)
 * Sphinx Search 2.2

Extended Sphinx uses MySQL Client 5.5.

License
-------------------

Sphinx Search container image is open-sourced software licensed under the [MIT license](http://opensource.org/licenses/MIT)