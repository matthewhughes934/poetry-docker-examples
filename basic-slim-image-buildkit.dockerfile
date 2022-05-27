# syntax=docker/dockerfile:1.4
# vim: filetype=dockerfile
FROM python:3.10-slim-buster
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

WORKDIR /proj
RUN \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        # To build C extensions we need a C compiler...
        gcc \
        # and some C library files
        libc-dev \
        # This is an optional extra for building uwsgi
        libpcre3-dev; \
    # following best practices at
    # https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#apt-get
    rm --recursive --force /var/lib/apt/lists/*; \
    pip install --progress-bar off --no-cache poetry

COPY pyproject.toml poetry.lock ./

# Cache poetry's cache
RUN mount=type=cache,target=/root/.cache \
    poetry install

COPY . ./
