#!/bin/bash
#--------------------------------------
# Script Name:  clean.sh
# Version:      1.1
# Authors:      skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         30 Oct 24
# Purpose:      Cleans up i2b2 Debian package build directories.
#--------------------------------------

set -euo pipefail

readonly DIR_CURRENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rm -rf "${DIR_CURRENT}/debian/build"
