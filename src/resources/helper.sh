#!/bin/bash
#--------------------------------------
# Script Name:  helper.sh
# Version:      1.0
# Author:       akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Provides two functions to add or remove key-value entries within the [Unit] section of a systemd service file located in /lib/systemd/system/.
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
