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
    rm --recursive --force /var/lib/apt/lists/*

COPY pyproject.toml poetry.lock ./

RUN \
    python -m venv /pip_venv; \
    python -m venv $VIRTUAL_ENV_PATH; \
    source $VIRTUAL_ENV_PATH/bin/activate; \
    /pip_venv/bin/pip install poetry; \
    /pip_venv/bin/poetry install --no-dev

FROM build as dev-build
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

RUN \
    source $VIRTUAL_ENV_PATH/bin/activate; \
    /pip_venv/bin/poetry install

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
