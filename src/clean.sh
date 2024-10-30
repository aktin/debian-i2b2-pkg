#!/bin/bash
#--------------------------------------
# Script Name:  clean.sh
# Version:      1.1
# Authors:      skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         30 Oct 24
# Purpose:      Cleans up i2b2 Debian package build directories.
#--------------------------------------

set -euo pipefail

# Define the root directory of the script
readonly DIR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

rm -rf "${DIR_ROOT}/debian/build"
