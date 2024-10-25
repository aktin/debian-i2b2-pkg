#!/bin/bash
#--------------------------------------
# Script Name:  common/build.sh
# Version:      1.0
# Author:       skurka@ukaachen.de, shuening@ukaachen.de, akombeiz@ukaachen.de
# Date:         24 Oct 24
# Purpose:      Automates the setup and configuration of the i2b2 web client, WildFly application server, and related resources.
#--------------------------------------

set -euo pipefail

# Check if variables are empty
if [ -z "${PACKAGE}" ]; then
    echo "\$PACKAGE is empty." >&2
    exit 1
fi
if [ -z "${VERSION}" ]; then
    echo "\$VERSION is empty." >&2
    exit 1
fi
if [ -z "${DIR_BUILD}" ]; then
    echo "\$DIR_BUILD is empty." >&2
    exit 1
fi

# Superdirectory this script is located with /resources appended, namely src/resources
readonly DIR_RESOURCES="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)/resources"

# Define DIR_DOWNLOADS as an absolute path
readonly DIR_DOWNLOADS="$(dirname "${DIR_RESOURCES}")/downloads"

function init_build_environment() {
    set -a
    . "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/versions"
    set +a
    if [ ! -d "${DIR_BUILD}" ]; then
      mkdir -p "${DIR_BUILD}"
    fi
    if [ ! -d "${DIR_DOWNLOADS}" ]; then
      mkdir "${DIR_DOWNLOADS}"
    fi
}

function clean_up_build_environment() {
    rm -rf "${DIR_BUILD}"
}

function download_i2b2_webclient() {
    local dir_webclient="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/v${VERSION_I2B2_WEBCLIENT}.zip" ]; then
      echo "Download i2b2 webclient v${VERSION_I2B2_WEBCLIENT}"
      wget "https://github.com/i2b2/i2b2-webclient/archive/v${VERSION_I2B2_WEBCLIENT}.zip" -P "${DIR_DOWNLOADS}"
    fi

    unzip -q "${DIR_DOWNLOADS}/v${VERSION_I2B2_WEBCLIENT}.zip" -d "${DIR_BUILD}"
    mkdir -p "$(dirname "${DIR_BUILD}${dir_webclient}")"
    mv "${DIR_BUILD}/i2b2-webclient-${VERSION_I2B2_WEBCLIENT}" "${DIR_BUILD}${dir_webclient}"
}

function config_i2b2_webclient() {
    local dir_webclient="${1}"
    local escaped_wildfly_host=$(printf '%s\n' "${2}" | sed 's/[\/&]/\\&/g')

    cp ${DIR_RESOURCES}/i2b2_config/* ${DIR_BUILD}${dir_webclient}/

    sed -i "s|loginDefaultUsername : \"demo\"|loginDefaultUsername : \"\"|" "${DIR_BUILD}${dir_webclient}/js-i2b2/i2b2_ui_config.js"
    sed -i "s|loginDefaultPassword : \"demouser\"|loginDefaultPassword : \"\"|" "${DIR_BUILD}${dir_webclient}/js-i2b2/i2b2_ui_config.js"

    sed -i 's|<div class="classic">For classic i2b2 webclient click <a href="#">here</a></div>||' "${DIR_BUILD}${dir_webclient}/js-i2b2/cells/PM/assets/login.html"

    sed -i "s|__WILDFLY_HOST__|${escaped_wildfly_host}|" "${DIR_BUILD}${dir_webclient}/proxy.php"
    sed -i "s|__WILDFLY_HOST__|${escaped_wildfly_host}|" "${DIR_BUILD}${dir_webclient}/i2b2_config_domains.json"
}

function download_wildfly() {
    local dir_wildfly_home="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/wildfly-${VERSION_WILDFLY}.zip" ]; then
        echo "Download WildFly ${VERSION_WILDFLY}"
        # wget "https://download.jboss.org/wildfly/${VERSION_WILDFLY}/wildfly-${VERSION_WILDFLY}.zip"  -P "${DIR_DOWNLOADS}"
        wget "https://github.com/wildfly/wildfly/releases/download/${VERSION_WILDFLY}/wildfly-${VERSION_WILDFLY}.zip" -P "${DIR_DOWNLOADS}"
    fi

    unzip -q "${DIR_DOWNLOADS}/wildfly-${VERSION_WILDFLY}.zip" -d "${DIR_BUILD}"
    mkdir -p "$(dirname "${DIR_BUILD}${dir_wildfly_home}")"
    mv "${DIR_BUILD}/wildfly-${VERSION_WILDFLY}" "${DIR_BUILD}${dir_wildfly_home}"
}

function init_wildfly_systemd() {
    local dir_wildfly_home="${1}"
    local dir_wildfly_config="${2}"
    local dir_systemd="${3}"

    mkdir -p "${DIR_BUILD}${dir_wildfly_config}" "${DIR_BUILD}${dir_systemd}"
    cp "${DIR_BUILD}${dir_wildfly_home}/docs/contrib/scripts/systemd/wildfly.service" "${DIR_BUILD}${dir_systemd}/"
    cp "${DIR_BUILD}${dir_wildfly_home}/docs/contrib/scripts/systemd/wildfly.conf" "${DIR_BUILD}${dir_wildfly_config}/"

    echo "WILDFLY_HOME=\"${dir_wildfly_home}\"" >>"${DIR_BUILD}${dir_wildfly_config}/wildfly.conf"

    cp "${DIR_BUILD}${dir_wildfly_home}/docs/contrib/scripts/systemd/launch.sh" "${DIR_BUILD}${dir_wildfly_home}/bin/"
}

function config_wildfly() {
    local dir_wildfly_home="${1}"

    # Increase JVM heap size
    sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" "${DIR_BUILD}${dir_wildfly_home}/bin/appclient.conf"
    sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" "${DIR_BUILD}${dir_wildfly_home}/bin/standalone.conf"

    # Fix CVE-2021-44228 (log4j2 vulnerability)
    echo 'JAVA_OPTS="$JAVA_OPTS -Dlog4j2.formatMsgNoLookups=true"' >>"${DIR_BUILD}${dir_wildfly_home}/bin/standalone.conf"

    # Prepare the config.cli file
    local config_cli_template="${DIR_RESOURCES}/wildfly_cli/config.cli"
    local config_cli_processed="${DIR_BUILD}${dir_wildfly_home}/bin/i2b2_config.cli"

    # Replace the placeholder in the config.cli file
    sed "s/__POSTGRES_JDBC_VERSION__/${VERSION_POSTGRES_JDBC}/g" "${config_cli_template}" > "${config_cli_processed}"

    # Run the JBoss CLI with the processed config.cli file
    "${DIR_BUILD}${dir_wildfly_home}/bin/jboss-cli.sh" --file="${config_cli_processed}"
}

function download_wildfly_jdbc() {
    local dir_wildfly_deployments="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/postgresql-${VERSION_POSTGRES_JDBC}.jar" ]; then
      echo "Download PostgreSQL JDBC ${VERSION_POSTGRES_JDBC}"
      wget "https://jdbc.postgresql.org/download/postgresql-${VERSION_POSTGRES_JDBC}.jar" -P "${DIR_DOWNLOADS}"
    fi

    cp "${DIR_DOWNLOADS}/postgresql-${VERSION_POSTGRES_JDBC}.jar" "${DIR_BUILD}${dir_wildfly_deployments}"
}

# TODO FIX THIS
function download_wildfly_i2b2() {
    local DIR_WILDFLY_DEPLOYMENTS="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/i2b2core-upgrade-${VERSION_I2B2}.zip" ]; then
      echo "i2b2core-upgrade-${VERSION_I2B2}.zip not found. Please download i2b2core-upgrade-${VERSION_I2B2}.zip from https://www.i2b2.org/software/index.html and move it to ${DIR_DOWNLOADS}. Afterwards re-run build." >&2
      exit 1
    fi

    unzip -q -j "${DIR_DOWNLOADS}/i2b2core-upgrade-${VERSION_I2B2}.zip" "i2b2/deployments/*" \
          -d "${DIR_BUILD}${DIR_WILDFLY_DEPLOYMENTS}"
}

function copy_database_for_postinstall() {
    local dir_db_postinstall="${1}"

    mkdir -p "$(dirname "${DIR_BUILD}${dir_db_postinstall}")"
    cp -r "${DIR_RESOURCES}/database" "${DIR_BUILD}${dir_db_postinstall}"
}

function copy_datasource_for_postinstall() {
    local dir_ds_postinstall="${1}"

    mkdir -p "$(dirname "${DIR_BUILD}${dir_ds_postinstall}")"
    cp -r "${DIR_RESOURCES}/datasource" "${DIR_BUILD}${dir_ds_postinstall}"
}

function copy_helper_functions_for_postinstall() {
    local dir_helper_postinstall="${1}"

    mkdir -p "$(dirname "${DIR_BUILD}${dir_helper_postinstall}")"
    cp "${DIR_RESOURCES}/helper.sh" "${DIR_BUILD}${dir_helper_postinstall}"
}
