#!/bin/bash
#--------------------------------------
# Script Name:  helper.sh
# Version:      1.3
# Authors:      akombeiz@ukaachen.de
# Date:         1 Nov 24
# Purpose:      Provides helper functions for database connection and service management tasks of maintainer scripts.
#--------------------------------------

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

connect_to_psql() {
  local max_retries=5
  local retry_interval=12
  local timeout=$((max_retries * retry_interval))
  local attempt=1

  log_info "Connecting to PostgreSQL via local UNIX socket..."
  export PSQL="sudo -u postgres psql"

  while ((attempt <= max_retries)); do
    if systemctl is-active --quiet postgresql && eval "${PSQL} -c '\l' >/dev/null 2>&1"; then
      log_success "Successfully connected to PostgreSQL"
      return 0
    fi
    if ((attempt == max_retries)); then
      log_error "Database connection timeout after ${timeout} seconds"
      return 1
    fi
    log_warn "Database not ready. Retrying in ${retry_interval}s... (Attempt ${attempt}/${max_retries})"
    ((attempt++))
    sleep "${retry_interval}"
  done
}

check_and_start_service() {
  local service="${1}"
  local max_retries=5
  local retry_delay=5
  local timeout=$((max_retries * retry_delay))
  log_info "Starting ${service} service..."

  if systemctl is-active --quiet "${service}"; then
    log_success "Service ${service} already running"
    return 0
  fi

  for ((i=1; i<=max_retries; i++)); do
    systemctl start "${service}"
    sleep "${retry_delay}"
    if systemctl is-active --quiet "${service}"; then
      log_success "Service ${service} started successfully"
      return 0
    fi
    if [ "$i" -eq "$max_retries" ]; then
      log_error "Failed to start ${service} after ${timeout} seconds"
      journalctl -u "${service}" --no-pager -n 20 >&2
      return 1
    fi
    log_warn "Retry ${i}/${max_retries} for ${service} (waiting ${retry_delay}s)"
  done
 }

stop_service() {
  local service="${1}"
  local max_wait=30
  log_info "Stopping ${service} service..."

  if ! systemctl is-active --quiet "${service}"; then
    log_warn "Service ${service} not running"
    return 0
  fi

  systemctl stop "${service}"
  local count=0
  while systemctl is-active --quiet "${service}"; do
    if ((count >= max_wait)); then
      log_error "Service ${service} stop timeout after ${max_wait}s"
      journalctl -u "${service}" --no-pager -n 20 >&2
      return 1
    fi
    if ((count % 5 == 0)); then
      log_info "Waiting for ${service} to stop... (${count}/${max_wait}s)"
    fi
    sleep 1
    ((count++))
  done
  log_success "Service ${service} stopped successfully"
}

cleanup_wildfly_deployment_markers() {
  local deploy_dir="${1:-/opt/wildfly/standalone/deployments}"
  log_info "Cleaning up WildFly deployment markers..."

  if [[ ! -d "${deploy_dir}" ]]; then
    log_warn "Deployment directory not found"
    return 0
  fi

  # Remove all deployment markers while preserving the actual artifacts
  find "${deploy_dir}" -type f \( \
    -name "*.deployed" -o \
    -name "*.dodeploy" -o \
    -name "*.failed" -o \
    -name "*.undeployed" \
    -name "*.swp" \
  \) -delete
  log_success "Deployment markers cleaned up"
}

# Removes specified datasource files from deployment directory
# (as datasources moved to standalone.xml in V1.6)
# @param $1 Deployment directory path (optional, defaults to WildFly deployments)
# @param $2... One or more datasource names without .xml extension
remove_datasource_files() {
  local deploy_dir="${1:-/opt/wildfly/standalone/deployments}"
  shift
  local -r datasources=("$@")
  log_info "Removing datasource files..."

  for ds in "${datasources[@]}"; do
    echo "${deploy_dir}/${ds}.xml"
    if ! rm -f "${deploy_dir}/${ds}.xml" 2>/dev/null; then
      log_error "Failed to remove ${ds} datasource files"
      return 1
    fi
  done
  log_success "Datasource files removed successfully"
  return 0
}
