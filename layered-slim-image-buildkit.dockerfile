# syntax=docker/dockerfile:1.4
# vim: filetype=dockerfile
# The virtual env _must_ be installed at the same path across images
# so use a variable to track this
ARG VIRTUAL_ENV_PATH="/opt/venv"

FROM python:3.10-slim-buster AS build
# Build image: construct a virtual env containing all our python deps
# then copy this across to a separate image
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

RUN \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        gcc \
        libc-dev \
        libpcre3-dev; \
    rm --recursive --force /var/lib/apt/lists/*; \
    pip install --progress-bar off --no-cache poetry

COPY pyproject.toml poetry.lock ./

# If we activate an virtualenv, Poetry will install into that
RUN \
    mount=type=cache,target=/root/.cache \
    python -m venv $VIRTUAL_ENV_PATH; \
    source $VIRTUAL_ENV_PATH/bin/activate; \
    poetry install;

FROM python:3.10-slim-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

WORKDIR /proj

RUN \
    apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        # The corresponding runtime library for libpcre3-dev
        libpcre3; \
    rm --recursive --force /var/lib/apt/lists/*

COPY --from=build $VIRTUAL_ENV_PATH $VIRTUAL_ENV_PATH

# Update PATH so we use programs in our virtualenv
ENV PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
ENV PYTHONPATH="/proj/src"

COPY . ./
