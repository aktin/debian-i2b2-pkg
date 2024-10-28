#!/bin/bash
#--------------------------------------
# Script Name:  build.sh
# Version:      1.0
# Author:       skurka@ukaachen.de, shuening@ukaachen.de, akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Automates building the Debian package for 'aktin-notaufnahme-i2b2'.
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
readonly DIR_BUILD="${DIR_CURRENT}/build/${PACKAGE}_${VERSION}"

load_common_files_and_prepare_environment() {
  source "$(dirname "${DIR_CURRENT}")/common/build.sh"
  clean_up_build_environment
  init_build_environment
}

prepare_package_environment() {
  download_and_extract_i2b2_webclient "/var/www/html/webclient"
  configure_i2b2_webclient "/var/www/html/webclient" "localhost"
  download_and_extract_wildfly "/opt/wildfly"
  configure_wildfly "/opt/wildfly"
  setup_wildfly_systemd "/opt/wildfly" "/etc/wildfly" "/lib/systemd/system"
  download_and_deploy_jdbc_driver "/opt/wildfly/standalone/deployments"
  download_and_deploy_i2b2_war "/opt/wildfly/standalone/deployments"
  copy_database_for_postinstall "/usr/share/${PACKAGE}/database"
  copy_helpers_for_postinstall "/usr/share/${PACKAGE}"
}

prepare_management_scripts_and_files() {
  mkdir -p "${DIR_BUILD}/DEBIAN"

  # Replace placeholders in the control file
  sed -e "s/__PACKAGE__/${PACKAGE}/g" -e "s/__VERSION__/${VERSION}/g" -e "s/__POSTGRESQL_VERSION__/${VERSION_POSTGRESQL}/g" "${DIR_CURRENT}/control" > "${DIR_BUILD}/DEBIAN/control"

  # Copy necessary scripts
  cp "${DIR_CURRENT}/config" "${DIR_BUILD}/DEBIAN/"
  cp "${DIR_CURRENT}/postinst" "${DIR_BUILD}/DEBIAN/"
  cp "${DIR_CURRENT}/prerm" "${DIR_BUILD}/DEBIAN/"

  # Process the postrm script by inserting SQL drop statements
  sed -e "/^__I2B2_DROP__/{r ${DIR_RESOURCES}/database/i2b2_postgres_drop.sql" -e "d;}" "${DIR_CURRENT}/postrm" > "${DIR_BUILD}/DEBIAN/postrm"
  chmod 0755 "${DIR_BUILD}/DEBIAN/postrm"
}

build_package() {
  dpkg-deb --build "${DIR_BUILD}"
  rm -rf "${DIR_BUILD}"
}

main() {
  set -euo pipefail
  load_common_files_and_prepare_environment
  prepare_package_environment
  prepare_management_scripts_and_files
  build_package
}

main
