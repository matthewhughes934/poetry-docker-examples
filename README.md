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

## Examples with Docker Buildkit

### Layered Slim Image with Cache mounting

`docker/dockerfile:1.2` introduced the [`RUN --mount`
syntax](https://github.com/moby/buildkit/blob/47e953b294d4a5b4a1dfd68aec788c3642dbf5a7/frontend/dockerfile/docs/reference.md#run---mount)
including `cache` mounts which:

> Mount a temporary directory to cache directories for compilers and package
> managers.

Importantly, these caches do not contribute to the size of the final image but
while allowing us to store `poetry`'s cache. This means repeated builds can
leverage this cache, though I don't think there's much benefit for these in
environments where images are build from a clean context each time, e.g. CI.

See `layered-slim-image-buildkit.dockerfile` for details, this builds are image
the same size as `layered-slim-image.dockerfile`. You can verify the cache
behaviour by adding some verbose flags to `poetry install` and after
invalidating the Docker cache for that stage observe that packages are not
fetched over the network.
