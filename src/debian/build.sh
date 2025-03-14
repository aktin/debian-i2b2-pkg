#!/bin/bash
#--------------------------------------
# Script Name:  build.sh
# Version:      1.2
# Authors:      skurka@ukaachen.de, shuening@ukaachen.de, akombeiz@ukaachen.de
# Date:         05 Dec 24
# Purpose:      Automates building the Debian package for 'aktin-notaufnahme-i2b2', including setup of required resources, configurations,
#               and dependencies.
#--------------------------------------

set -euo pipefail

readonly PACKAGE_NAME="aktin-notaufnahme-i2b2"
readonly TRIGGER_PREFIX="aktin"

CLEANUP=false
SKIP_BUILD=false
FULL_CLEAN=false

usage() {
  echo "Usage: $0 [--cleanup] [--skip-deb-build] [--full-clean]" >&2
  echo "  --cleanup          Optional: Remove build directory after package creation" >&2
  echo "  --skip-deb-build   Optional: Skip the debian package build step" >&2
  echo "  --full-clean       Optional: Remove build and downloads directories before starting" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --cleanup)
      CLEANUP=true
      shift
      ;;
    --skip-deb-build)
      SKIP_BUILD=true
      shift
      ;;
    --full-clean)
      FULL_CLEAN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unexpected argument '$1'" >&2
      usage
      ;;
  esac
done

# Define relevant directories as absolute paths
readonly DIR_DEBIAN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_SRC="$(dirname "${DIR_DEBIAN}")"
readonly DIR_RESOURCES="${DIR_SRC}/resources"
readonly DIR_DOWNLOADS="${DIR_SRC}/downloads"

# Load version-specific variables from file
set -a
. "${DIR_RESOURCES}/versions"
set +a
readonly DIR_BUILD="${DIR_SRC}/build/${PACKAGE_NAME}_${PACKAGE_VERSION}"

clean_up_build_environment() {
  echo "Cleaning up previous build environment..."
  rm -rf "${DIR_BUILD}"
  if [[ "${FULL_CLEAN}" == true ]]; then
    echo "Performing full clean..."
    rm -rf "${DIR_SRC}/build"
    rm -rf "${DIR_DOWNLOADS}"
  fi
}

init_build_environment() {
  echo "Initializing build environment..."
  if [[ ! -d "${DIR_BUILD}" ]]; then
    mkdir -p "${DIR_BUILD}"
  fi
  if [[ ! -d "${DIR_DOWNLOADS}" ]]; then
    mkdir -p "${DIR_DOWNLOADS}"
  fi
}

download_and_extract_i2b2_webclient() {
  local dir_webclient="${1}"
  echo "Downloading i2b2 webclient v${I2B2_WEBCLIENT_VERSION}..."

  if [[ -f "${DIR_DOWNLOADS}/v${I2B2_WEBCLIENT_VERSION}.zip" ]]; then
    echo "Using cached webclient download"
  else
    wget "https://github.com/i2b2/i2b2-webclient/archive/v${I2B2_WEBCLIENT_VERSION}.zip" -P "${DIR_DOWNLOADS}"
  fi

  mkdir -p "$(dirname "${DIR_BUILD}${dir_webclient}")"
  unzip -q "${DIR_DOWNLOADS}/v${I2B2_WEBCLIENT_VERSION}.zip" -d "${DIR_BUILD}"
  mv "${DIR_BUILD}/i2b2-webclient-${I2B2_WEBCLIENT_VERSION}" "${DIR_BUILD}${dir_webclient}"
}

configure_i2b2_webclient() {
  local dir_webclient="${1}"
  echo "Configuring i2b2 webclient..."

  # Modify default login credentials
  sed -i "s|loginDefaultUsername : \"demo\"|loginDefaultUsername : \"\"|" "${DIR_BUILD}${dir_webclient}/js-i2b2/i2b2_ui_config.js"
  sed -i "s|loginDefaultPassword : \"demouser\"|loginDefaultPassword : \"\"|" "${DIR_BUILD}${dir_webclient}/js-i2b2/i2b2_ui_config.js"

  # Remove unnecessary link to old I2B2 Webclient
  sed -i 's|<div class="classic">For classic i2b2 webclient click <a href="#">here</a></div>||' "${DIR_BUILD}${dir_webclient}/js-i2b2/cells/PM/assets/login.html"

  # Set host configuration
  cp "${DIR_RESOURCES}/httpd/i2b2_config_domains.json" "${DIR_BUILD}${dir_webclient}/i2b2_config_domains.json"
}

download_and_extract_wildfly() {
  local dir_wildfly_home="${1}"
  echo "Downloading WildFly ${WILDFLY_VERSION}..."

  if [[ -f "${DIR_DOWNLOADS}/wildfly-${WILDFLY_VERSION}.zip" ]]; then
    echo "Using cached WildFly download"
  else
    wget "https://download.jboss.org/wildfly/${WILDFLY_VERSION}/wildfly-${WILDFLY_VERSION}.zip" -P "${DIR_DOWNLOADS}"
  fi

  mkdir -p "$(dirname "${DIR_BUILD}${dir_wildfly_home}")"
  unzip -q "${DIR_DOWNLOADS}/wildfly-${WILDFLY_VERSION}.zip" -d "${DIR_BUILD}"
  mv "${DIR_BUILD}/wildfly-${WILDFLY_VERSION}" "${DIR_BUILD}${dir_wildfly_home}"
}

configure_wildfly() {
  local dir_wildfly_home="${1}"
  echo "Configuring WildFly server..."

  # Adjust JVM heap size for better performance
  sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" "${DIR_BUILD}${dir_wildfly_home}/bin/appclient.conf"
  sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" "${DIR_BUILD}${dir_wildfly_home}/bin/standalone.conf"

  # Fix CVE-2021-44228 (log4j2 vulnerability)
  echo 'JAVA_OPTS="$JAVA_OPTS -Dlog4j2.formatMsgNoLookups=true"' >> "${DIR_BUILD}${dir_wildfly_home}/bin/standalone.conf"

  # Set up WildFly CLI for configuration
  local processed_config_cli="${DIR_BUILD}${dir_wildfly_home}/bin/add-i2b2-config.cli"
  sed "s/__POSTGRES_JDBC_VERSION__/${POSTGRES_JDBC_VERSION}/g" "${DIR_RESOURCES}/wildfly/add-i2b2-config.cli" > "${processed_config_cli}"

  # Apply configuration via JBoss CLI
  "${DIR_BUILD}${dir_wildfly_home}/bin/jboss-cli.sh" --file="${processed_config_cli}"

  # Cleanup configuration patch history to reduce space
  rm -rf "${DIR_BUILD}${dir_wildfly_home}/standalone/configuration/standalone_xml_history/current/"*
}

setup_wildfly_systemd() {
  local dir_wildfly_home="${1}"
  local dir_wildfly_config="${2}"
  local dir_systemd="${3}"
  echo "Setting up WildFly systemd service..."

  mkdir -p "${DIR_BUILD}${dir_wildfly_config}" "${DIR_BUILD}${dir_systemd}"
  # Set up systemd service for WildFly, enabling automatic startup and management
  cp "${DIR_BUILD}${dir_wildfly_home}/docs/contrib/scripts/systemd/wildfly.service" "${DIR_BUILD}${dir_systemd}/"
  cp "${DIR_BUILD}${dir_wildfly_home}/docs/contrib/scripts/systemd/wildfly.conf" "${DIR_BUILD}${dir_wildfly_config}/"
  echo "WILDFLY_HOME=\"${dir_wildfly_home}\"" >> "${DIR_BUILD}${dir_wildfly_config}/wildfly.conf"
  cp "${DIR_BUILD}${dir_wildfly_home}/docs/contrib/scripts/systemd/launch.sh" "${DIR_BUILD}${dir_wildfly_home}/bin/"
}

download_and_copy_jdbc_driver() {
  local dir_wildfly_deployments="${1}"
  echo "Downloading PostgreSQL JDBC driver ${POSTGRES_JDBC_VERSION}..."

  if [[ -f "${DIR_DOWNLOADS}/postgresql-${POSTGRES_JDBC_VERSION}.jar" ]]; then
    echo "Using cached JDBC driver"
  else
    wget "https://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar" -P "${DIR_DOWNLOADS}"
  fi

  cp "${DIR_DOWNLOADS}/postgresql-${POSTGRES_JDBC_VERSION}.jar" "${DIR_BUILD}${dir_wildfly_deployments}"
}

download_and_copy_i2b2_war() {
  local dir_wildfly_deployments="${1}"
  echo "Downloading i2b2 WAR ${I2B2_VERSION}..."

 if [[ -f "${DIR_DOWNLOADS}/i2b2.war" ]]; then
    echo "Using cached i2b2 WAR"
  else
    wget "https://www.aktin.org/software/repo/org/i2b2/${I2B2_VERSION}/i2b2.war" -P "${DIR_DOWNLOADS}"
  fi

  cp "${DIR_DOWNLOADS}/i2b2.war" "${DIR_BUILD}${dir_wildfly_deployments}"
}

copy_sql_scripts() {
  local dir_db="${1}"
  echo "Copying SQL scripts..."
  mkdir -p "${DIR_BUILD}${dir_db}"
  cp -r "${DIR_RESOURCES}/sql/"* "${DIR_BUILD}${dir_db}"
}

copy_helper_scripts() {
  local dir_helper="${1}"
  echo "Copying helper scripts..."
  mkdir -p "${DIR_BUILD}${dir_helper}"
  cp "${DIR_RESOURCES}/helper.sh" "${DIR_BUILD}${dir_helper}"
}

prepare_management_scripts_and_files() {
  echo "Preparing Debian package management files..."
  mkdir -p "${DIR_BUILD}/DEBIAN"

  # Replace placeholders
  sed -e "s|__PACKAGE_NAME__|${PACKAGE_NAME}|g" -e "s|__PACKAGE_VERSION__|${PACKAGE_VERSION}|g" "${DIR_DEBIAN}/control" > "${DIR_BUILD}/DEBIAN/control"
  sed -e "s|__TRIGGER_PREFIX__|${TRIGGER_PREFIX}|g" -e "s|__POSTGRES_JDBC_VERSION__|${POSTGRES_JDBC_VERSION}|g" "${DIR_DEBIAN}/postinst" > "${DIR_BUILD}/DEBIAN/postinst"
  sed -e "/^__I2B2_DROP_STATEMENT__/{r ${DIR_RESOURCES}/sql/i2b2_drop.sql" -e "d;}" "${DIR_DEBIAN}/postrm" > "${DIR_BUILD}/DEBIAN/postrm"

  # Copy necessary scripts
  cp "${DIR_DEBIAN}/prerm" "${DIR_BUILD}/DEBIAN/prerm"

  # Set proper executable permissions
  chmod 0755 "${DIR_BUILD}/DEBIAN/"*
}

build_package() {
  if [[ "${SKIP_BUILD}" == false ]]; then
    echo "Building Debian package..."
    dpkg-deb --build "${DIR_BUILD}"
    if [[ "${CLEANUP}" == true ]]; then
      echo "Cleaning up build directory..."
      rm -rf "${DIR_BUILD}"
    fi
  else
    echo "Debian build skipped"
  fi
}

main() {
  set -euo pipefail
  clean_up_build_environment
  init_build_environment
  download_and_extract_i2b2_webclient "/var/www/html/webclient"
  configure_i2b2_webclient "/var/www/html/webclient"
  download_and_extract_wildfly "/opt/wildfly"
  configure_wildfly "/opt/wildfly"
  setup_wildfly_systemd "/opt/wildfly" "/etc/wildfly" "/lib/systemd/system"
  download_and_copy_jdbc_driver "/opt/wildfly/standalone/deployments"
  download_and_copy_i2b2_war "/opt/wildfly/standalone/deployments"
  copy_sql_scripts "/usr/share/${PACKAGE_NAME}/sql"
  copy_helper_scripts "/usr/share/${PACKAGE_NAME}"
  prepare_management_scripts_and_files
  build_package
}

main
