# Poetry + Docker Examples

Basic summary:

  - Avoid using any caches from `pip`, `poetry`, or `apt`
  - Install all packages into a virtualenv via the standard library's `venv`
  - Use a non-root user to run container
  - Minimise number of layers
  - Minimise build time, mostly via maximising cache-hits

The general trend is that there is a trade off between simplicity and final
image size.

There is a `Makefile` to make testing a bit simpler. You can run `make
<image-name>` where `image-name` is any of the `*.dockerfile` files with the
`.dockerfile` suffix removed, e.g. `make basic-full-image`. You can additionally
pass `BUILD_ARGS` to pass extra args to `docker build` e.g. `make
basic-full-image BUILD_ARGS='--no-cache'`

## Overview

### `basic-full-image`

About as simple as possible. This just uses a full Debian based python image and
installs all the dependencies on top.

### `basic-slim-image`

Uses a slim Debian based Python image. This means we have to manually add some
required build and run-time dependencies. Specifically:

* A C compiler (`gcc`) since we need to build a C extension
* `libc-dev` development files and headers for the GNU C library
* `libprce3-dev` just for demonstration. This is just an optional extra for
`uwsgi`

We save space on all the extra bits installed on the full Debian image that we
don't need.

### `layered-slim-image`

Builds all dependencies into a virtualenv a slim Debian based Python image. This
virtualenv is then copied into a final slim Debian based python image which also
includes some required run-time dependencies. Specifically:

* `libprce3` just for demonstration. This is just an optional extra for
`uwsgi`, it is the run-time counterpart to `libprce3-dev`

We save space on the difference in size between the build-time and run-time
dependencies.

### `multi-layared-slim-image`

All stages are slim Debian based Python images. Constructs a base builder image
with build dependencies then constructs an image for building only the run-time
Python package and one for building only the development Python packages
(testing, linting etc.). Then creates a run-time image that installs the
run-time system dependencies and copies the virtual environment from the
run-time builder. Then creates a development image based off the run-time one
and merges the development virtualenv with the production one.

This is by far the most complicated setup, and requires managing two images (the
production one and the dev one for testing etc.) but should result in the
smallest production image.

### `layered-slim-image-pip-wheels`

A different approach to the dual layer build. Instead of building dependencies
into a virtualenv and copying that across, build their wheels and copy them
across and finally install them in the production image.

This results in a large image since the production image includes both the
installed dependencies and the wheels they were installed from (even though we
`rm` them, since they were included in a layer from a `COPY` instruction).
However, copying the wheels _should be_ quicker than copying the entire
virtualenv since there are fewer files: one `*.whl` file per dependency rather
than however many files the installed package expands to (though I've yet to
benchmark this).

## Sizes

Sizes taken from

``` console
docker images --format '{{.Size}}' <image-tag>
```

| Image Name | Size |
| --- | --- |
| `basic-full-image` | 1.05GB |
| `basic-slim-image` | 398MB |
| `layered-slim-image` | 260MB |
| `multi-layered-slim-image` | 190MB |
| `multi-layared-slim-image-dev` | 324MB |
| `layered-slim-image-pip-wheels` | 282MB |

## Uncached build times

Building via:

``` console
time make <image-tag> BUILD_ARGS='--no-cache'
```

Note: these values depend a lot on network latency/bandwidth (since most time is
spent fetching packages). Though intuitively we expect the `basic-full-image` to
be quickest since it only includes one call of each `apt-get update`, `apt-get
install` `pip install`, and `poetry install`.

| Image Name | Build Time |
| --- | --- |
| `basic-full-image` | 0m39.450s |
| `basic-slim-image` | 0m56.897s |
| `layered-slim-image` | 0m50.445s |
| `multi-layered-slim-image` | 1m4.042s |
| `multi-layared-slim-image-dev` | 0m55.733s |

## Code change build times

Simulating a change to the code under `src/` which shouldn't require
reinstalling any dependencies.

| Image Name | Build Time |
| --- | --- |
| `basic-full-image` | 0m4.812s |
| `basic-slim-image` | 0m4.629s |
| `layered-slim-image` | 0m4.204s |
| `multi-layered-slim-image` | 0m3.799s |
| `multi-layared-slim-image-dev` | 0m8.553s |

## New dependency build times

Simulating a new dependency by just adding a line to `pyproject.toml`

| Image Name | Build Time |
| --- | --- |
| `basic-full-image` | 0m27.440s |
| `basic-slim-image` | 0m30.197s |
| `layered-slim-image` | 0m21.804s |
| `multi-layered-slim-image` | 0m22.052s |
| `multi-layared-slim-image-dev` | 0m36.885s |

```
$ docker build --quiet --file multi-layered-slim-image.dockerfile . >/dev/null
$ echo '# cache busting comment' >> pyproject.toml
$ time docker build --quiet --file multi-layered-slim-image.dockerfile . >/dev/null

real	0m26.507s
user	0m0.254s
sys	0m0.084s
```

## Examples with Docker Buildkit

### Basic Slim Image with Cache mounting

With Docker BuildKit you can use a [cache
mount](https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/syntax.md#run---mounttypecache)
to cache some data between builds. An ideal target for this is the cache used
by pip and poetry. Since we're using Docker Buildkit, we ex

Build size:

```
$ DOCKER_BUILDKIT=1 docker build --progress plain --quiet --tag basic-slim-image-buildkit --file basic-slim-image-buildkit.dockerfile . >/dev/null
$ docker images basic-slim-image-buildkit --format "{{ .Size }}"
408MB
```

The size difference appears to be the size of the stored cache (grep for
`errexit` to find commands from our image, and `tac` just to make the order
follow the `dockerfile`):

```
$ docker history \
    --no-trunc \
    --format '{{ .CreatedBy }}\t{{ .Size }}\t{{ .Comment }}' \
    --human basic-slim-image \
    | grep -- '-o errexit' \
    | grep --invert-match '#(nop)' \
    | tac
/bin/bash -o errexit -o nounset -o pipefail -c apt-get update;     apt-get install --assume-yes --no-install-recommends         gcc         libc-dev         libpcre3-dev;     rm --recursive --force /var/lib/apt/lists/*;     pip install --progress-bar off --no-cache poetry	163MB	
/bin/bash -o errexit -o nounset -o pipefail -c POETRY_CACHE_DIR=/tmp/poetry-cache poetry install;     rm --recursive /tmp/poetry-cache	12.4MB	
```

Compare with:

```
$ docker history \
    --no-trunc \
    --format '{{ .CreatedBy }}\t{{ .Size }}' \
    --human basic-slim-image-buildkit \
    | grep -- '-o errexit' \
    | grep --invert-match '#(nop)' \
    | tac
SHELL [/bin/bash -o errexit -o nounset -o pipefail -c]	0B
RUN /bin/bash -o errexit -o nounset -o pipefail -c apt-get update;     apt-get install --assume-yes --no-install-recommends         gcc         libc-dev         libpcre3-dev;     rm --recursive --force /var/lib/apt/lists/*;     pip install --progress-bar off --no-cache poetry # buildkit	163MB
RUN /bin/bash -o errexit -o nounset -o pipefail -c mount=type=cache,target=/root/.cache     poetry install # buildkit	128MB
```

We see the `apt` and `pip` install command took up the same space, but the
`poetry install` command was much larger in the second image where we persist
the cache.

Uncached build time:

```
$ time DOCKER_BUILDKIT=1 docker build --no-cache --progress plain --quiet --file basic-slim-image-buildkit.dockerfile . >/dev/null

real	0m36.558s
user	0m0.076s
sys	0m0.017s
```

Build with simulated new dependency. This is where we hope for a speed up due
to being able to re-use `poetry`'s cache

```
$ DOCKER_BUILDKIT=1 docker build --progress plain --quiet --file basic-slim-image-buildkit.dockerfile . >/dev/null
$ echo '# cache busting comment' >> pyproject.toml
$ time DOCKER_BUILDKIT=1 docker build --progress plain --quiet --file basic-slim-image-buildkit.dockerfile . >/dev/null

real	0m15.862s
user	0m0.036s
sys	0m0.043s
```

### Layered Slim Image with Cache mounting

Size, note we no longer have cache in the final image, since it exists only in
the intermediate layer:

```
$ DOCKER_BUILDKIT=1 docker build --quiet --progress plain --tag layered-slim-image-buildkit --file layered-slim-image-buildkit.dockerfile . >/dev/null
$ docker images layered-slim-image-buildkit --format '{{ .Size }}'
211MB
```

Uncached build time

```
$ time DOCKER_BUILDKIT=1 docker build --progress plain --no-cache --file layered-slim-image-buildkit.dockerfile . >/dev/null

real	0m35.408s
user	0m0.283s
sys	0m0.102s
```

Build with simulated new dependency:

```
$ DOCKER_BUILDKIT=1 docker build --quiet --progress plain --file layered-slim-image-buildkit.dockerfile . >/dev/null
$ time DOCKER_BUILDKIT=1 docker build --quiet --progress plain --file layered-slim-image-buildkit.dockerfile . >/dev/null

real	0m16.724s
user	0m0.059s
sys	0m0.011s
```
