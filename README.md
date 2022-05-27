# Poetry + Docker Examples

## Basic Full Image

See `basic-full-image.dockerfile`.

* `poetry` install is cached in the top layer (never reinstalled)
* Reinstalls all dependencies if `pyproject.toml` or `poetry.lock` are changed

Size:

```
$ docker build --quiet --tag basic-full-image --file basic-full-image.dockerfile . >/dev/null
$ docker images basic-full-image --format "{{.Size}}"
912MB
```

Uncached build time:

```
$ time docker build --quiet --no-cache --file basic-full-image.dockerfile . >/dev/null

real	0m25.796s
user	0m0.305s
sys	0m0.099s
```

Build time after simulating adding a new dependency (with build cache), this
skips the install of `pip` and does a full re-install of all dependencies:

```
# warm up the cache
$ docker build --quiet --file basic-full-image.dockerfile . >/dev/null
# simulate a new dependency
$ echo '# cache busting comment' >> pyproject.toml
$ time docker build --quiet --file basic-full-image.dockerfile . >/dev/null

real	0m17.363s
user	0m0.223s
sys	0m0.061s
```

## Basic Slim Image

Using a slim Debian image. We now need to install some extra dependencies:

* A C compiler (`gcc`) since we need to build a C extension
* `libc-dev` development files and headers for the GNU C library
* `libprce3-dev` just for demonstration. This is just an optional extra for
`uwsgi`

* Installation of the extra deps listed above is cached in the top layer (never reinstalled)
* `poetry` install is cached in the top layer (never reinstalled)
* Reinstalls all dependencies if `pyproject.toml` or `poetry.lock` are changed

Building:

```
$ docker build --tag basic-slim-image --file basic-slim-image.dockerfile .
$ docker images basic-slim-image --format "{{.Size}}"
293MB
```

Uncached build time, takes longer than the full image since we have extra
packages to install:

```
$ time docker build --no-cache --quiet --file basic-slim-image.dockerfile . >/dev/null

real	0m33.953s
user	0m0.259s
sys	0m0.096s
```

Build with simulated new dependency:

```
$ docker build --quiet --file basic-slim-image.dockerfile . >/dev/null
$ echo '# cache busting comment' >> pyproject.toml
$ time docker build --quiet --file basic-slim-image.dockerfile . >/dev/null

real	0m14.528s
user	0m0.249s
sys	0m0.067s
```

## Slim Image with Stages

This relies on the assumption we can copy a virtual env (created from the
[stdlib `venv`](https://docs.python.org/3/library/venv.html)) between images
which requires (at least):

* The virtualenvs have the same absolute paths in each image, this is because
  shebangs are hard-coded in the programs in the virtualenv
* The same runtime libraries are available in each image, e.g. if a Python
  package is built in one image and linked against a PCRE library, the runtime
  version of that library must exist in the same path in the second image.

Size:

```
$ docker build --tag layered-slim-image --file layered-slim-image.dockerfile .
$ docker images layered-slim-image --format "{{.Size}}"
211MB
```

Uncached build time, takes longer since each layer needs to install some extra
packages (but these should be cached for all future builds):

```
$ time docker build --quiet --no-cache --file layered-slim-image.dockerfile . >/dev/null

real	0m46.029s
user	0m0.261s
sys	0m0.103s
```

Build with simulated new dependency:

```
$ docker build --quiet --file layered-slim-image.dockerfile . >/dev/null
$ echo '# cache busting comment' >> pyproject.toml
$ time docker build --quiet --file layered-slim-image.dockerfile . >/dev/null

real	0m21.174s
user	0m0.283s
sys	0m0.122s
```

## Slim Images with multiple Stages

Production image:

```
$ docker build --target production --tag multi-layered-slim-image --file multi-layered-slim-iamge.dockerfile .
$ docker images multi-layered-slim-image --format "{{.Size}}"
140MB
```

Development image:

```
$ docker build --target development --tag multi-layered-slim-image-development --file multi-layered-slim-iamge.dockerfile .
$ docker images multi-layered-slim-image-development --format "{{.Size}}"
233MB
```

Build time, takes longer since there are two sets of `apt install` calls,
transferring context between images also takes time (that grows as the size of
this, i.e. the size of Python packages, grows):

```
$ time docker build --quiet --no-cache --file multi-layered-slim-iamge.dockerfile . >/dev/null

real	0m57.473s
user	0m0.243s
sys	0m0.065s
```

```
$ docker build --quiet --file multi-layered-slim-iamge.dockerfile . >/dev/null
$ echo '# cache busting comment' >> pyproject.toml
$ time docker build --quiet --file multi-layered-slim-iamge.dockerfile . >/dev/null

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
