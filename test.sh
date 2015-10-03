#!/bin/bash

set -e

echo ""
echo "-- Building Sphinx image"
docker build -t sphinx-test .

echo ""
echo "-- Run mysql container"
docker run --name db-test -d -e 'MYSQL_USER=test' -e 'MYSQL_PASS=pass' -e 'MYSQL_CACHE_ENABLED=true' -e 'DB_NAME=db_test' romeoz/docker-mysql; sleep 10

echo ""
echo "-- Create table"
docker exec -it db-test mysql -uroot -e 'CREATE TABLE db_test.items (id INT NOT NULL AUTO_INCREMENT, content TEXT, PRIMARY KEY(id)) ENGINE = INNODB;'; sleep 5

echo ""
echo "-- Insert records"
docker exec -it db-test mysql -uroot -e 'INSERT INTO db_test.items (content) VALUES ("about dog"),("about cat");'; sleep 5

echo ""
echo "-- Run sphinx container"
docker run --name sphinx-test -d --link db-test:db-test sphinx-test; sleep 10
echo ""
echo "-- Indexing records"
docker exec -it sphinx-test indexer --config /etc/sphinxsearch/sphinx.conf --all --rotate; sleep 10

echo ""
echo "-- Testing"
docker exec -it db-test mysql -P9306 -h$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' sphinx-test) -e "SELECT * FROM items_index WHERE MATCH('cat');" | grep -wc "2"



echo ""
echo "-- Testing backup"
#docker exec -it db-test mysql -P9306 -h$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' sphinx-test) -e "FLUSH RTINDEX myrtindex"
docker run -it --rm --volumes-from sphinx-test -e 'SPHINX_MODE=backup' -v $(pwd)/vol/backup:/tmp/backup sphinx-test; sleep 5

echo ""
echo "-- Clear"
docker rm -f -v sphinx-test; sleep 5
echo ""
echo "--- Recovery from backup"
docker run --name sphinx-recovery -d --link db-test:db-test -e 'SPHINX_IMPORT=default' -v $(pwd)/vol/backup:/tmp/backup  sphinx-test; sleep 10

echo ""
echo "--- Checking backup"
docker exec -it db-test mysql -P9306 -h$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' sphinx-recovery) -e "SELECT * FROM items_index WHERE MATCH('cat');" | grep -wc "2"
docker run -it --rm -e 'SPHINX_CHECK=default' -e 'INDEX_NAME=items_index' -v $(pwd)/vol/backup:/tmp/backup  sphinx-test; sleep 5

echo ""
echo "-- Clear"
docker rm -f -v $(sudo docker ps -aq); sleep 5
docker rmi -f sphinx-test; sleep 5
rm -rf $(pwd)/vo*

echo ""
echo "-- Done"