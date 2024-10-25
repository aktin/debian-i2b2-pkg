#!/bin/bash
#--------------------------------------
# Script Name:  clean_all.sh
# Version:      1.0
# Author:       skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         25 Oct 24
# Purpose:      Removes the i2b2 build directories for Debian packages and Docker images.
#--------------------------------------

set -euo pipefail

# Get the directory where this script is located
readonly DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

main() {
    rm -rf "${DIR_ROOT}/debian/build" "${DIR_ROOT}/docker/build"
}

main
