# Poetry + Docker Examples

## Basic Full Image

See `basic-full-image.dockerfile`.

* `poetry` install is cached in the top layer (never reinstalled)
* Reinstalls all dependencies if `pyproject.toml` or `poetry.lock` are changed

Size:

```
$ docker images basic-full-image --format "{{.Size}}"
1.08GB
```

## Basic Slim Image

Using a slim Debian image. We now need to install some extra dependencies:

* A C compiler (`gcc`) since we need to build a C extension
* `libc-dev` development files and headers for the GNU C library
* `libprce3-dev` just for demonstration. This is just an optional extra for
`uwsgi`

* Installation of the extra deps listed above is cachedin the top layer (never reinstalled)
* `poetry` install is cached in the top layer (never reinstalled)
* Reinstalls all dependencies if `pyproject.toml` or `poetry.lock` are changed

Building:

```
docker build --tag layered-slim-image --file layered-slim-image.dockerfile .
```

Size:

```
$ docker images basic-slim-image --format "{{.Size}}"
424MB
```

## Slim Image with Stages

Size:

```
$ docker build --tag layered-slim-image --file layered-slim-image.dockerfile .
$ docker images layered-slim-image --format "{{.Size}}"
248MB
```

## Slim Images with multiple Stages

Production image

```
$ docker build --target production --tag multi-layered-slim-image --file multi-layered-slim-iamge.dockerfile .
$ docker images multi-layered-slim-image --format "{{.Size}}"
140MB
```

Development image:

```
$ docker build --target development --tag multi-layered-slim-image-development --file multi-layered-slim-iamge.dockerfile .
$ docker images multi-layered-slim-image-development --format "{{.Size}}"
211MB
```

## Slim Images with build cache

[](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#apt-get)