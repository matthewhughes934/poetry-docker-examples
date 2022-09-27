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

# If we activate an virtualenv, Poetry will install into that
RUN --mount=type=cache,target=/tmp/poetry-cache \
    poetry config cache-dir /tmp/poetry-cache && \
    poetry install --no-interaction --no-root

FROM python:3.10-slim-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH
ENV PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
ENV VIRTUAL_ENV="$VIRTUAL_ENV_PATH"

RUN \
    apt-get update && \
    apt-get install --assume-yes --no-install-recommends \
        # The corresponding runtime library for libpcre3-dev
        libpcre3 && \
    rm --recursive --force /var/lib/apt/lists/* && \
    useradd --user-group --create-home --shell /bin/bash user

COPY --chown=user:user --from=build $VIRTUAL_ENV_PATH $VIRTUAL_ENV_PATH
COPY --chown=user:user ./ /home/user/proj
WORKDIR /home/user/proj
RUN poetry install --only-root

RUN ["pytest"]
