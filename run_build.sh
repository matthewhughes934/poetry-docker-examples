#!/bin/bash

set -o errexit -o nounset -o pipefail

if [ $# -ne 1 ]
then
    echo "Usage: $0 image-name" >&2
    exit 1
fi

image_name="$1"

PS4="$ "
set -x
# warm up the cache
make "$image_name" >/dev/null
docker images "$image_name" --format '{{.Size}}'

# simulate a new dependency
echo '# cache busting comment' >> pyproject.toml
time make "$image_name" >/dev/null

# uncached build time
time make "$image_name" BUILD_ARGS='--no-cache' >/dev/null
set +x

git checkout -- pyproject.toml
