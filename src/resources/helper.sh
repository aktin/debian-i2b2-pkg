#!/bin/bash
#--------------------------------------
# Script Name:  helper.sh
# Version:      1.1
# Authors:      akombeiz@ukaachen.de
# Date:         30 Oct 24
# Purpose:      Provides helper functions for database management tasks of maintainer scripts.
#--------------------------------------

connect_to_psql() {
  # Source the Debconf configuration module
  . /usr/share/debconf/confmodule

  # Extract the base name for Debconf settings (e.g., package name prefix)
  local debconf_name
  debconf_name="$(echo "${DPKG_MAINTSCRIPT_PACKAGE}" | awk -F '-' '{print $1"-"$2}')"

  # Retrieve connection type from Debconf and set up the PSQL command accordingly
  db_get "${debconf_name}/db_conn"
  if [[ "${RET}" == "unix" ]]; then
    readonly PSQL="sudo -u postgres psql"
    echo "Connecting to PostgreSQL via local UNIX socket."
  else
    # Retrieve connection details from Debconf and construct the PSQL command for TCP/IP
    local host port user pass
    db_get "${debconf_name}/db_host"; host="${RET}"
    db_get "${debconf_name}/db_port"; port="${RET}"
    db_get "${debconf_name}/db_user"; user="${RET}"
    db_get "${debconf_name}/db_pass"; pass="${RET}"

    export PSQL="psql postgresql://${user}:${pass}@${host}:${port}?sslmode=require"
    echo "Connecting to PostgreSQL via TCP/IP at ${host}:${port}."
  fi
}

wait_for_psql_connection() {
  local wait_count=0
  local max_retries=12
  local retry_interval=5
  local timeout=60

  echo "Waiting for PostgreSQL to be ready..."
    while true; do
      if systemctl is-active --quiet postgresql; then
        # Verify actual connection
        if eval "${PSQL} -c '\l' >/dev/null 2>&1"; then
          echo "Successfully connected to PostgreSQL."
          return 0
        fi
      fi

      if ((wait_count >= max_retries)); then
        echo "Error: Database connection timeout after ${timeout} seconds." >&2
        return 1
      fi

      echo "Database not ready. Retrying in ${retry_interval} seconds... (Attempt ${wait_count}/${max_retries})"
      wait_count=$((wait_count + 1))
      sleep "${retry_interval}"
    done
}
