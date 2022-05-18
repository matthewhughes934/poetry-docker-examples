# vim: filetype=dockerfile
FROM python:3.10-slim-buster
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

WORKDIR /proj
RUN \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        gcc \
        libc-dev \
        libpcre3-dev; \
    rm --recursive --force /var/lib/apt/lists/*; \
    pip install poetry

COPY pyproject.toml poetry.lock ./

RUN poetry install

COPY . ./
