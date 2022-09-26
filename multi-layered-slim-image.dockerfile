# vim: filetype=dockerfile
ARG VIRTUAL_ENV_PATH="/opt/venv"

# build stage: install poetry and _only_ the runtime dependencies
# into a virtualenv
FROM python:3.10-slim-buster AS build
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH
ENV PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
ENV VIRTUAL_ENV="$VIRTUAL_ENV_PATH"

RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        gcc \
        libc-dev \
        libpcre3-dev && \
    rm --recursive --force /var/lib/apt/lists/* && \
    python -m venv $VIRTUAL_ENV_PATH && \
    pip install --progress-bar off --no-cache 'poetry>=1.2.0'

COPY pyproject.toml poetry.lock ./
RUN poetry install --no-cache --only main

# dev-build stage: install poetry and _only_ the dev dependencies
# into a virtualenv
FROM build as dev-build
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH
ENV PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
ENV VIRTUAL_ENV="$VIRTUAL_ENV_PATH"

RUN poetry install --only dev --no-cache

# production: copy the virtualenv from build and install the current project
FROM python:3.10-slim-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH
ENV PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
ENV VIRTUAL_ENV="$VIRTUAL_ENV_PATH"

RUN apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        libpcre3 && \
    rm --recursive --force /var/lib/apt/lists/* && \
    useradd --user-group --create-home --shell /bin/bash user

COPY --chown=user:user --from=build $VIRTUAL_ENV_PATH $VIRTUAL_ENV_PATH
COPY --chown=user:user ./ /home/user/proj
WORKDIR /home/user/proj
RUN poetry install --only-root

# development: extend production and merge the virtualenv from dev-build
FROM production AS development
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH

COPY --from=dev-build --chown=user:user $VIRTUAL_ENV_PATH $VIRTUAL_ENV_PATH

RUN ["pytest"]
