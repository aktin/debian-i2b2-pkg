#!/bin/bash
set -euo pipefail

readonly PACKAGE="aktin-notaufnahme-i2b2"

if [ -z "${VERSION+x}" ]; then
    readonly VERSION="${1:-}"
    if [ -z "${VERSION}" ]; then
        echo "\$VERSION is empty."
        exit 1
    fi
fi

readonly DIR_CURRENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
readonly DIR_BUILD="${DIR_CURRENT}/build"

function load_common_files_and_prepare_environment() {
    . "$(dirname "${DIR_CURRENT}")/common/build.sh"
    clean_up_build_environment
    init_build_environment
}

function load_docker_environment_variables() {
    export "$(cat ${DIR_CURRENT}/.env | xargs)"
}

function prepare_wildfly_docker() {
    mkdir -p "${DIR_BUILD}/wildfly"
    cp -r "${DIR_CURRENT}/wildfly" "${DIR_BUILD}/"
    cp "${DIR_RESOURCES}/wildfly_cli/config.cli" "${DIR_BUILD}/wildfly/"

    download_wildfly "/wildfly"
    download_wildfly_jdbc "/wildfly"
    download_wildfly_i2b2 "/wildfly"
}

function prepare_postgresql_docker() {
    mkdir -p "${DIR_BUILD}/database"
    cp "${DIR_CURRENT}/database/Dockerfile" "${DIR_BUILD}/database/"
    copy_database_for_postinstall "/database/sql"
    cp "${DIR_CURRENT}/database/sql/update_wildfly_host.sql" "${DIR_BUILD}/database/sql/i2b2_update_wildfly_host.sql"
}

function prepare_apache2_docker() {
    mkdir -p "${DIR_BUILD}/httpd"
    cp "${DIR_CURRENT}/httpd/Dockerfile" "${DIR_BUILD}/httpd/"
    download_i2b2_webclient "/httpd/i2b2webclient"
    config_i2b2_webclient "/httpd/i2b2webclient" "wildfly"
}

function clean_up_old_docker_images() {
    LIST_IMAGES=("${NAMESPACE_IMAGE_I2B2}database" "${NAMESPACE_IMAGE_I2B2}wildfly" "${NAMESPACE_IMAGE_I2B2}httpd")
    for IMAGE in "${LIST_IMAGES[@]}"; do
        # Stop and remove running container if exists
        ID_CONTAINER="$(docker ps -q -f ancestor="${IMAGE}:latest")"
        if [ -n "${ID_CONTAINER}" ]; then
            docker stop "${ID_CONTAINER}" || true
            docker rm "${ID_CONTAINER}" || true
        fi
        # Remove image
        ID_IMAGE="$(docker images -q "${IMAGE}:latest")"
        if [ -n "${ID_IMAGE}" ]; then
            docker image rm "${ID_IMAGE}" || true
        fi
    done
}

function build_docker_images() {
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
    prepare_postgresql_docker
    prepare_apache2_docker
    clean_up_old_docker_images
    build_docker_images
}

main
