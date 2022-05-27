# vim: filetype=dockerfile
ARG VIRTUAL_ENV_PATH="/opt/venv"

FROM python:3.10-slim-buster AS build
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

RUN \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        gcc \
        libc-dev \
        libpcre3-dev; \
    rm --recursive --force /var/lib/apt/lists/*; \
    python -m venv /pip_venv; \
    /pip_venv/bin/pip install --progress-bar off --no-cache poetry

COPY pyproject.toml poetry.lock ./

RUN \
    python -m venv $VIRTUAL_ENV_PATH; \
    source $VIRTUAL_ENV_PATH/bin/activate; \
    POETRY_CACHE_DIR=/tmp/poetry-cache /pip_venv/bin/poetry install --no-dev; \
    rm --recursive /tmp/poetry-cache

FROM build as dev-build
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

RUN \
    source $VIRTUAL_ENV_PATH/bin/activate; \
    POETRY_CACHE_DIR=/tmp/poetry-cache /pip_venv/bin/poetry install; \
    rm --recursive /tmp/poetry-cache

FROM python:3.10-slim-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

WORKDIR /proj

RUN \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        libpcre3; \
    rm --recursive --force /var/lib/apt/lists/*

COPY --from=build $VIRTUAL_ENV_PATH $VIRTUAL_ENV_PATH

ENV PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
ENV PYTHONPATH="/proj/src"

COPY . ./

FROM production AS development
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

COPY --from=dev-build $VIRTUAL_ENV_PATH $VIRTUAL_ENV_PATH
