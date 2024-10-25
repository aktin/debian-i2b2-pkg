#!/bin/bash
#--------------------------------------
# Script Name:  build.sh
# Version:      1.0
# Author:       shuening@ukaachen.de, skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Builds Docker images for the 'aktin-notaufnahme-i2b2' application by preparing the environment,
#               loading variables, setting up Docker images, cleaning up old images, and building new ones using Docker Compose.
#--------------------------------------

set -euo pipefail

readonly PACKAGE="aktin-notaufnahme-i2b2"

# Determine VERSION: Use environment variable or first script argument
VERSION="${VERSION:-${1:-}}"
if [[ -z "${VERSION}" ]]; then
  echo "Error: VERSION is not specified." >&2
  echo "Usage: $0 <version>"
  exit 1
fi
readonly VERSION

# Get the directory where this script is located
readonly DIR_CURRENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
readonly DIR_BUILD="${DIR_CURRENT}/build"

load_common_files_and_prepare_environment() {
  source "$(dirname "${DIR_CURRENT}")/common/build.sh"
  clean_up_build_environment
  init_build_environment
}

load_docker_environment_variables() {
  if [ -f "${DIR_CURRENT}/.env" ]; then
    export "$(cat ${DIR_CURRENT}/.env | xargs)"
  else
    echo "Error: .env file not found in ${DIR_CURRENT}" >&2
    exit 1
  fi
}

prepare_wildfly_docker() {
  echo "Preparing WildFly Docker image..."
  mkdir -p "${DIR_BUILD}/wildfly"
  cp -r "${DIR_CURRENT}/wildfly/Dockerfile" "${DIR_BUILD}/wildfly/"
  download_wildfly "/wildfly/wildfly"
  config_wildfly "/wildfly/wildfly"
  download_wildfly_jdbc "/wildfly/wildfly/standalone/deployments"
  download_wildfly_i2b2 "/wildfly/wildfly/standalone/deployments"
}

prepare_postgresql_docker() {
  echo "Preparing PostgreSQL Docker image..."
  mkdir -p "${DIR_BUILD}/database"
  cp "${DIR_CURRENT}/database/Dockerfile" "${DIR_BUILD}/database/"
  copy_database_for_postinstall "/database/sql"
  cp "${DIR_CURRENT}/database/sql/update_wildfly_host.sql" "${DIR_BUILD}/database/sql/i2b2_update_wildfly_host.sql"
}

prepare_apache2_docker() {
  echo "Preparing Apache2 Docker image..."
  mkdir -p "${DIR_BUILD}/httpd"
  cp "${DIR_CURRENT}/httpd/Dockerfile" "${DIR_BUILD}/httpd/"
  download_i2b2_webclient "/httpd/webclient"
  config_i2b2_webclient "/httpd/webclient" "wildfly"
}

clean_up_old_docker_images2() {
  echo "Cleaning up old Docker images and containers..."
  local images=("database" "wildfly" "httpd")
  for image in "${images[@]}"; do
    local full_image_name="${NAMESPACE_IMAGE_I2B2}-${image}"

    # Stop and remove running containers based on the image
    local container_ids
    container_ids=$(docker ps -a -q --filter "ancestor=${full_image_name}:latest")
    if [ -n "$container_ids" ]; then
      docker stop $container_ids || true
      docker rm $container_ids || true
    fi

    # Remove the Docker image
    if docker images "${full_image_name}:latest" -q >/dev/null; then
      docker image rm "${full_image_name}:latest" || true
    fi
  done
}

build_docker_images() {
  echo "Building Docker images..."
  cwd="$(pwd)"
  cd "${DIR_CURRENT}"
  docker compose build
  cd "${cwd}"
}

main() {
  set -euo pipefail
  load_common_files_and_prepare_environment
  load_docker_environment_variables
  prepare_wildfly_docker
  #prepare_postgresql_docker
  #prepare_apache2_docker
  #clean_up_old_docker_images
  #build_docker_images
}

main
