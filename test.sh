#!/bin/bash

set -e

echo "-- Building Sphinx image"
docker build -t sphinx_test .
docker network create sphinx_test_net
DIR_VOLUME=$(pwd)/vol
mkdir -p ${DIR_VOLUME}/backup

echo
echo "-- Testing Sphinx + PostgreSQL"
echo
echo "-- Run postgresql container"
docker run --name db-test -d --net sphinx_test_net -e 'DB_NAME=db_test' -e 'DB_USER=admin' -e 'DB_PASS=pass' romeoz/docker-postgresql; sleep 20
echo
echo "-- Create table"
docker exec -it db-test sudo -u postgres psql db_test -c "CREATE TABLE items (id SERIAL, content TEXT);"
echo
echo "-- Sets a permission on database"
docker exec -it db-test sudo -u postgres psql db_test -c "GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO admin;GRANT SELECT ON ALL TABLES IN SCHEMA public TO admin;"
echo
echo "-- Insert records"
docker exec -it db-test sudo -u postgres psql db_test -c "INSERT INTO items (content) VALUES ('about dog'),('about cat');"; sleep 5
echo
echo "-- Run sphinx container"
docker run --name sphinx_test -d --net sphinx_test_net -e "SPHINX_MODE=indexing" -e "SPHINX_CONF=/etc/sphinxsearch/sphinx_pgsql.conf" sphinx_test; sleep 10
echo
echo "-- Install MySQL client"
docker exec -it sphinx_test bash -c 'apt-get update && apt-get install -y mysql-client && rm -rf /var/lib/apt/lists/*'; sleep 10
echo
echo "-- Testing"
docker exec -it sphinx_test mysql -P9306 -h127.0.0.1 -e "SELECT id FROM items_index WHERE MATCH('cat');" | grep -wc "2"

echo
echo "-- Testing backup"
docker run -it --rm --volumes-from sphinx_test -e 'SPHINX_MODE=backup' -v ${DIR_VOLUME}/backup:/tmp/backup sphinx_test; sleep 10

echo
echo "-- Clear"
docker rm -f -v sphinx_test; sleep 5
echo
echo "-- Restore from backup"
docker run --name sphinx_restore -d --net sphinx_test_net -e "SPHINX_CONF=/etc/sphinxsearch/sphinx_pgsql.conf" -e 'SPHINX_RESTORE=default' -v ${DIR_VOLUME}/backup:/tmp/backup  sphinx_test; sleep 20

echo
echo "-- Install MySQL client"
docker exec -it sphinx_restore bash -c 'apt-get update && apt-get install -y mysql-client && rm -rf /var/lib/apt/lists/*'; sleep 10
echo
echo "-- Checking backup"
docker exec -it sphinx_restore mysql -P9306 -h127.0.0.1 -e "SELECT id FROM items_index WHERE MATCH('cat');" | grep -wc "2"
docker run -it --rm -e 'SPHINX_CHECK=default' -e "SPHINX_CONF=/etc/sphinxsearch/sphinx_pgsql.conf" -e 'INDEX_NAME=items_index' -v ${DIR_VOLUME}/backup:/tmp/backup  sphinx_test | grep -wc 'Success'; sleep 5

echo
echo "-- Clear"
docker rm -f -v sphinx_restore db-test; sleep 5
rm -rf ${DIR_VOLUME}


echo
echo
echo "-- Testing Sphinx + MySQL"
echo
echo "-- Run mysql container"
mkdir -p ${DIR_VOLUME}/backup
docker run --name db-test -d --net sphinx_test_net -e 'MYSQL_USER=admin' -e 'MYSQL_PASS=pass' -e 'MYSQL_CACHE_ENABLED=true' -e 'DB_NAME=db_test' romeoz/docker-mysql; sleep 20

echo
echo "-- Create table"
docker exec -it db-test mysql -uroot -e 'CREATE TABLE db_test.items (id INT NOT NULL AUTO_INCREMENT, content TEXT, PRIMARY KEY(id)) ENGINE = INNODB;'; sleep 5

echo
echo "-- Insert records"
docker exec -it db-test mysql -uroot -e 'INSERT INTO db_test.items (content) VALUES ("about dog"),("about cat");'; sleep 5

echo
echo "-- Run sphinx container"
docker run --name sphinx_test -d --net sphinx_test_net -e "SPHINX_MODE=indexing" sphinx_test; sleep 10

echo
echo "-- Testing"
docker exec -it db-test mysql -P9306 -hsphinx_test -e "SELECT * FROM items_index WHERE MATCH('cat');" | grep -wc "2"


echo
echo "-- Testing backup"
#docker exec -it db-test mysql -P9306 -h$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' sphinx_test) -e "FLUSH RTINDEX myrtindex"
docker run -it --rm --volumes-from sphinx_test -e 'SPHINX_MODE=backup' -v ${DIR_VOLUME}/backup:/tmp/backup sphinx_test; sleep 10

echo
echo "-- Clear"
docker rm -f -v sphinx_test; sleep 5
echo
echo "-- Restore from backup"
docker run --name sphinx_restore -d --net sphinx_test_net -e 'SPHINX_RESTORE=default' -v ${DIR_VOLUME}/backup:/tmp/backup  sphinx_test; sleep 20

echo
echo "-- Checking backup"
docker exec -it db-test mysql -P9306 -hsphinx_restore -e "SELECT * FROM items_index WHERE MATCH('cat');" | grep -wc "2"
docker run -it --rm -e 'SPHINX_CHECK=default' -e 'INDEX_NAME=items_index' -v ${DIR_VOLUME}/backup:/tmp/backup  sphinx_test | grep -wc 'Success'; sleep 5

echo
echo "-- Clear"
docker rm -f -v sphinx_restore db-test; sleep 5
docker network rm sphinx_test_net
docker rmi -f sphinx_test; sleep 5
rm -rf ${DIR_VOLUME}

echo
echo "-- Done"