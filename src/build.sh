#!/bin/bash
#--------------------------------------
# Script Name:  build.sh
# Version:      1.1
# Authors:      skurka@ukaachen.de, akombeiz@ukaachen.de
# Date:         30 Oct 24
# Purpose:      Builds i2b2 Debian package components for the specified version.
#--------------------------------------

set -euo pipefail

# Verify if a version is specified as an argument
readonly VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "Error: VERSION is not specified." >&2
  echo "Usage: $0 <version>"
  exit 1
fi

readonly DIR_CURRENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DIR_CURRENT}/debian/build.sh" "${VERSION}"
