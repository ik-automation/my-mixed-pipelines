#!/bin/bash

set -euo pipefail

: "${FLYWAY_URL}"
: "${DB_USERNAME}"
: "${DB_PASSWORD}"
: "${APPLY}"
: "${FLYWAY_WORKING_DIRECTORY}"

on_exit() {
	rm -f ${FLYWAY_WORKING_DIRECTORY}/conf/flyway.conf
	unset FLYWAY_URL
	unset DB_PASSWORD
}
trap on_exit EXIT

echo "====================="
echo "User: ${DB_USERNAME}"
echo "====================="

mkdir -p ${FLYWAY_WORKING_DIRECTORY}/conf
cp -r ${FLYWAY_WORKING_DIRECTORY}/ddl ${FLYWAY_WORKING_DIRECTORY}/sql
rm -rf ${FLYWAY_WORKING_DIRECTORY}/ddl
ls -la $FLYWAY_WORKING_DIRECTORY
cat >${FLYWAY_WORKING_DIRECTORY}/conf/flyway.conf <<-EOS
flyway.mixed=true
flyway.outOfOrder=false
flyway.ignoreMissingMigrations=false
flyway.baselineOnMigrate=false
flyway.locations=sql
EOS

execute() {
	flyway -url="${FLYWAY_URL}" \
		-user="${DB_USERNAME}" \
		-password="${DB_PASSWORD}" \
    -workingDirectory="${FLYWAY_WORKING_DIRECTORY}" \
		"$1"
}

execute info
# execute baseline

if [ "$APPLY" = true ] ; then
  echo "Migrate Versions"
  execute migrate
fi

echo "After migration"
execute info
