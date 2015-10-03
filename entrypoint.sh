#!/bin/bash
set -e

SPHINX_MODE=${SPHINX_MODE:-}
SPHINX_BACKUP_DIR=${SPHINX_BACKUP_DIR:-"/tmp/backup"}
SPHINX_BACKUP_FILENAME=${SPHINX_BACKUP_FILENAME:-"backup.last.tar.gz"}
SPHINX_IMPORT=${SPHINX_IMPORT:-}
SPHINX_CHECK=${SPHINX_CHECK:-}
INDEX_NAME=${INDEX_NAME:-}
SPHINX_ROTATE_BACKUP=${SPHINX_ROTATE_BACKUP:-true}

create_backup_dir() {
    if [[ ! -d ${SPHINX_BACKUP_DIR}/ ]]; then
        mkdir -p ${SPHINX_BACKUP_DIR}/
    fi
    chmod -R 0755 ${SPHINX_BACKUP_DIR}
}

create_data_dir() {
  mkdir -p ${SPHINX_DATADIR}
  chmod -R 0700 ${SPHINX_DATADIR}
}

rotate_backup()
{
    echo "Rotate backup..."

    if [[ ${SPHINX_ROTATE_BACKUP} == true ]]; then
        WEEK=$(date +"%V")
        MONTH=$(date +"%b")
        let "INDEX = WEEK % 5" || true
        if [[ ${INDEX} == 0  ]]; then
          INDEX=4
        fi

        test -e ${SPHINX_BACKUP_DIR}/backup.${INDEX}.tar.gz && rm ${SPHINX_BACKUP_DIR}/backup.${INDEX}.tar.gz
        mv ${SPHINX_BACKUP_DIR}/backup.tar.gz ${SPHINX_BACKUP_DIR}/backup.${INDEX}.tar.gz
        echo "Create backup file: ${SPHINX_BACKUP_DIR}/backup.${INDEX}.tar.gz"

        test -e ${SPHINX_BACKUP_DIR}/backup.${MONTH}.tar.gz && rm ${SPHINX_BACKUP_DIR}/backup.${MONTH}.tar.gz
        ln ${SPHINX_BACKUP_DIR}/backup.${INDEX}.tar.gz ${SPHINX_BACKUP_DIR}/backup.${MONTH}.tar.gz
        echo "Create backup file: ${SPHINX_BACKUP_DIR}/backup.${MONTH}.tar.gz"

        test -e ${SPHINX_BACKUP_DIR}/backup.last.tar.gz && rm ${SPHINX_BACKUP_DIR}/backup.last.tar.gz
        ln ${SPHINX_BACKUP_DIR}/backup.${INDEX}.tar.gz ${SPHINX_BACKUP_DIR}/backup.last.tar.gz
        echo "Create backup file:  ${SPHINX_BACKUP_DIR}/backup.last.tar.gz"
    else
        mv ${SPHINX_BACKUP_DIR}/backup.tar.gz ${SPHINX_BACKUP_DIR}/backup.last.tar.gz
        echo "Create backup file: ${SPHINX_BACKUP_DIR}/backup.last.tar.gz"
    fi
}

import_backup()
{
    echo "Import dump..."
    FILE=$1
    if [[ ${FILE} == default ]]; then
        FILE="${SPHINX_BACKUP_DIR}/${SPHINX_BACKUP_FILENAME}"
    fi
    if [[ ! -f "${FILE}" ]]; then
        echo "Unknown backup: ${FILE}"
        exit 1
    fi
    create_data_dir
    tar -C ${SPHINX_DATADIR} -xf ${FILE}
}

sed -i "s~SPHINX_DATADIR~${SPHINX_DATADIR}~g" ${SPHINX_CONF}
sed -i "s~SPHINX_LOGDIR~${SPHINX_LOGDIR}~g" ${SPHINX_CONF}
sed -i "s~SPHINX_RUN~${SPHINX_RUN}~g" ${SPHINX_CONF}

if [[ ${SPHINX_MODE} == backup ]]; then
    echo "Backup..."
    if [[ ! -d ${SPHINX_DATADIR} ]]; then
        echo "No such directory: ${SPHINX_DATADIR}"
        exit 1
    fi
    create_backup_dir
    cd ${SPHINX_DATADIR}
    tar --ignore-failed-read -zcvf ${SPHINX_BACKUP_DIR}/backup.tar.gz  *.sp* *.ram *.kill *.meta binlog.*
    cd -
    rotate_backup
    exit 0
fi

# Import dump
if [[ -n ${SPHINX_IMPORT} ]]; then
    import_backup ${SPHINX_IMPORT}
fi

 # Check backup
if [[ -n ${SPHINX_CHECK} ]]; then

  echo "Check backup..."
  if [[ -z ${INDEX_NAME} ]]; then
    echo "Unknown database. INDEX_NAME does not null"
    exit 1;
  fi

  if [[ ! -d ${SPHINX_DATADIR} || -z $(ls -A ${SPHINX_DATADIR}) ]]; then
        import_backup ${SPHINX_CHECK}
  fi

  if [[ $(indextool --config ${SPHINX_CONF} --check ${INDEX_NAME} | grep -w "check passed")  ]]; then
    echo "Success checking backup"
  else
    echo "Fail checking backup"
    exit 1
  fi

  exit 0
fi

# allow arguments to be passed to Sphinx search
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
fi

# default behaviour is to launch Sphinx search
if [[ -z ${1} ]]; then
  echo "Starting Sphinx search demon..."
  exec $(which searchd) --config ${SPHINX_CONF} --nodetach ${EXTRA_ARGS}
else
  exec "$@"
fi