# vim: filetype=dockerfile
FROM python:3.10-buster
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

WORKDIR /proj
# No progress bar just to make output a bit cleaner in CI
# no cache to save some space; we'll use docker's caching to avoid re-installs
RUN pip install --progress-bar off --no-cache poetry

COPY pyproject.toml poetry.lock ./

RUN \
    POETRY_CACHE_DIR=/tmp/poetry-cache poetry install; \
    # similar to pip, we don't need to keep the cache around
    rm --recursive /tmp/poetry-cache

COPY . ./
