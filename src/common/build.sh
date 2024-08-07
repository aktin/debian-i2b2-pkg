#!/bin/bash
set -euo pipefail

# Check if variables are empty
if [ -z "${PACKAGE}" ]; then
    echo "\$PACKAGE is empty."
    exit 1
fi
if [ -z "${VERSION}" ]; then
    echo "\$VERSION is empty."
    exit 1
fi
if [ -z "${DIR_BUILD}" ]; then
    echo "\$DIR_BUILD is empty."
    exit 1
fi

# Superdirectory this script is located in + /resources, namely src/resources
readonly DIR_RESOURCES="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)/resources"

readonly DIR_DOWNLOADS="../downloads"

function init_build_environment() {
    set -a
    . "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/versions"
    set +a
    mkdir -p "${DIR_BUILD}"

    if [ ! -d "${DIR_DOWNLOADS}" ]; then
      mkdir "${DIR_DOWNLOADS}"
    fi
}

function clean_up_build_environment() {
    rm -rf "${DIR_BUILD}"
}

function download_i2b2_webclient() {
    local DIR_WEBCLIENT="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/v${VERSION_I2B2_WEBCLIENT}.zip" ]; then
      echo "Download i2b2 webclient v${VERSION_I2B2_WEBCLIENT}"
      wget "https://github.com/i2b2/i2b2-webclient/archive/v${VERSION_I2B2_WEBCLIENT}.zip" -P "${DIR_DOWNLOADS}"
    fi

    unzip "${DIR_DOWNLOADS}/v${VERSION_I2B2_WEBCLIENT}.zip" -d "${DIR_BUILD}"

    mkdir -p "$(dirname "${DIR_BUILD}${DIR_WEBCLIENT}")"
    mv "${DIR_BUILD}/i2b2-webclient-${VERSION_I2B2_WEBCLIENT}" "${DIR_BUILD}${DIR_WEBCLIENT}"
}

function config_i2b2_webclient() {
    local DIR_WEBCLIENT="${1}"
    local WILDFLY_HOST="${2}"

    cp ${DIR_RESOURCES}/i2b2_config/* ${DIR_BUILD}${DIR_WEBCLIENT}/

    sed -i "s|loginDefaultUsername : \"demo\"|loginDefaultUsername : \"\"|" "${DIR_BUILD}${DIR_WEBCLIENT}/js-i2b2/i2b2_ui_config.js"
    sed -i "s|loginDefaultPassword : \"demouser\"|loginDefaultPassword : \"\"|" "${DIR_BUILD}${DIR_WEBCLIENT}/js-i2b2/i2b2_ui_config.js"

    sed -i "s|__WILDFLY_HOST__|${WILDFLY_HOST}|" "${DIR_BUILD}${DIR_WEBCLIENT}/proxy.php"
    sed -i "s|__WILDFLY_HOST__|${WILDFLY_HOST}|" "${DIR_BUILD}${DIR_WEBCLIENT}/i2b2_config_domains.json"
}

function download_wildfly() {
    local DIR_WILDFLY_HOME="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/wildfly-${VERSION_WILDFLY}.zip" ]; then
      echo "Download Wildfly ${VERSION_WILDFLY}"
#      wget "https://download.jboss.org/wildfly/${VERSION_WILDFLY}/wildfly-${VERSION_WILDFLY}.zip"  -P "${DIR_DOWNLOADS}"
      wget "https://github.com/wildfly/wildfly/releases/download/${VERSION_WILDFLY}/wildfly-${VERSION_WILDFLY}.zip" -P "${DIR_DOWNLOADS}"
    fi

    unzip "${DIR_DOWNLOADS}/wildfly-${VERSION_WILDFLY}.zip" -d "${DIR_BUILD}"
    mkdir -p "$(dirname "${DIR_BUILD}${DIR_WILDFLY_HOME}")"
    mv "${DIR_BUILD}/wildfly-${VERSION_WILDFLY}" "${DIR_BUILD}${DIR_WILDFLY_HOME}"
}

function init_wildfly_systemd() {
    local DIR_WILDFLY_HOME="${1}"
    local DIR_WILDFLY_CONFIG="${2}"
    local DIR_SYSTEMD="${3}"

    mkdir -p "${DIR_BUILD}${DIR_WILDFLY_CONFIG}" "${DIR_BUILD}${DIR_SYSTEMD}"
    cp "${DIR_BUILD}${DIR_WILDFLY_HOME}/docs/contrib/scripts/systemd/wildfly.service" "${DIR_BUILD}${DIR_SYSTEMD}/"
    cp "${DIR_BUILD}${DIR_WILDFLY_HOME}/docs/contrib/scripts/systemd/wildfly.conf" "${DIR_BUILD}${DIR_WILDFLY_CONFIG}/"

    echo "WILDFLY_HOME=\"${DIR_WILDFLY_HOME}\"" >>"${DIR_BUILD}${DIR_WILDFLY_CONFIG}/wildfly.conf"

    cp "${DIR_BUILD}${DIR_WILDFLY_HOME}/docs/contrib/scripts/systemd/launch.sh" "${DIR_BUILD}${DIR_WILDFLY_HOME}/bin/"
}

function config_wildfly() {
    local DIR_WILDFLY_HOME="${1}"

    # increases JVM heap size
    sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" "${DIR_BUILD}${DIR_WILDFLY_HOME}/bin/appclient.conf"
    sed -i "s/-Xms64m -Xmx512m/-Xms1024m -Xmx2g/" "${DIR_BUILD}${DIR_WILDFLY_HOME}/bin/standalone.conf"

    # fix CVE-2021-44228 (log4j2 vulnerability)
    echo "JAVA_OPTS=\"\$JAVA_OPTS -Dlog4j2.formatMsgNoLookups=true\"" >>"${DIR_BUILD}${DIR_WILDFLY_HOME}/bin/standalone.conf"

   "${DIR_BUILD}${DIR_WILDFLY_HOME}/bin/jboss-cli.sh" --file="${DIR_RESOURCES}/wildfly_cli/config.cli"
}

function download_wildfly_jdbc() {
    local DIR_WILDFLY_DEPLOYMENTS="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/postgresql-${VERSION_POSTGRES_JDBC}.jar" ]; then
      echo "Download Postgres ${VERSION_POSTGRES_JDBC}"
      wget "https://jdbc.postgresql.org/download/postgresql-${VERSION_POSTGRES_JDBC}.jar" -P "${DIR_DOWNLOADS}"
    fi

    cp "${DIR_DOWNLOADS}/postgresql-${VERSION_POSTGRES_JDBC}.jar" "${DIR_BUILD}${DIR_WILDFLY_DEPLOYMENTS}"
}

function download_wildfly_i2b2() {
    local DIR_WILDFLY_DEPLOYMENTS="${1}"

    if [ ! -f "${DIR_DOWNLOADS}/i2b2core-upgrade-${VERSION_I2B2}.zip" ]; then
      echo "i2b2core-upgrade-${VERSION_I2B2}.zip not found. Please download i2b2core-upgrade-${VERSION_I2B2}.zip from https://www.i2b2.org/software/index.html and move it to ${DIR_DOWNLOADS}."
      exit 1
    fi

    unzip -j "${DIR_DOWNLOADS}/i2b2core-upgrade-${VERSION_I2B2}.zip" "i2b2/deployments/i2b2.war" \
          -d "${DIR_BUILD}${DIR_WILDFLY_DEPLOYMENTS}"

}

function copy_database_for_postinstall() {
    local DIR_DB_POSTINSTALL="${1}"

    mkdir -p "$(dirname "${DIR_BUILD}${DIR_DB_POSTINSTALL}")"
    cp -r "${DIR_RESOURCES}/database" "${DIR_BUILD}${DIR_DB_POSTINSTALL}"
}

function copy_datasource_for_postinstall() {
    local DIR_DS_POSTINSTALL="${1}"

    mkdir -p "$(dirname "${DIR_BUILD}${DIR_DS_POSTINSTALL}")"
    cp -r "${DIR_RESOURCES}/datasource" "${DIR_BUILD}${DIR_DS_POSTINSTALL}"
}

function copy_helper_functions_for_postinstall() {
    local DIR_HELPER_POSTINSTALL="${1}"

    mkdir -p "$(dirname "${DIR_BUILD}${DIR_HELPER_POSTINSTALL}")"
    cp "${DIR_RESOURCES}/helper.sh" "${DIR_BUILD}${DIR_HELPER_POSTINSTALL}"
}
