#!/bin/bash
#--------------------------------------
# Script Name:  helper.sh
# Version:      1.1
# Author:       akombeiz@ukaachen.de
# Date:         30 Oct 24
# Purpose:      Provides helper functions for system configuration and database management tasks for maintainer scripts.
#--------------------------------------

# Function to add a value to a key within the [Unit] section of a systemd service file
add_entry_to_service() {
  local service_name="$1"
  local key="$2"
  local value="$3"
  local service_file="/lib/systemd/system/${service_name}"

  # Check if the key exists in the service file
  if grep -q "^${key}=" "${service_file}"; then
    # Get the current line with the key
    local line
    line="$(grep "^${key}=" "${service_file}")"

    # If the value is not already in the line, append it
    if [[ "${line}" != *"${value}"* ]]; then
      line+=" ${value}"
      # Update the line in the service file
      sed -i "s/^${key}=.*/${line}/" "${service_file}"
    fi
  else
    # Add the key and value after the [Unit] section
    sed -i "/^\[Unit\]$/a ${key}=${value}" "${service_file}"
  fi
}

# Function to remove a value from a key within the [Unit] section of a systemd service file
remove_entry_from_service() {
  local service_name="$1"
  local key="$2"
  local value="$3"
  local service_file="/lib/systemd/system/${service_name}"

  # Check if the key exists in the service file
  if grep -q "^${key}=" "${service_file}"; then
    # Get the current line with the key
    local line
    line="$(grep "^${key}=" "${service_file}")"

    # If the value is in the line, remove it
    if [[ "${line}" == *"${value}"* ]]; then
      # Remove the value from the line
      line="${line//${value}/}"
      # If the key has no values left, delete the key line
      if [[ -z "$(cut -d'=' -f2 <<<"${line}" | tr -d ' ')" ]]; then
        sed -i "/^${key}=.*/d" "${service_file}"
      else
        # Update the line in the service file
        sed -i "s/^${key}=.*/${line}/" "${service_file}"
      fi
    fi
  fi
}

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

  while ! systemctl start postgresql 2>/dev/null; do
    if (( wait_count < max_retries )); then
      echo "Database not yet available. Retrying in ${retry_interval} seconds..."
      wait_count=$((wait_count + 1))
      sleep "${retry_interval}"
    else
      echo "Database could not be started after ${max_retries} attempts. Aborting..."
      exit 1
    fi
  done
}
