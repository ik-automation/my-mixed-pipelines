#!/bin/bash

set -eu pipefail

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

echo "Fix Schema for database"
ls -la $FLYWAY_WORKING_DIRECTORY

execute info
echo "Repair DB"
execute repair

echo "Migration FAILED. Please review scripts where its failed"
current_state=$(execute info)
cat "$current_state"
