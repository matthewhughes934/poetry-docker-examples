# vim: filetype=dockerfile
# The virtual env _must_ be installed at the same path across images
# so use a variable to track this
ARG VIRTUAL_ENV_PATH="/opt/venv"

# build stage: install poetry and all dependencies into a virtualenv
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
RUN poetry install --no-interaction --no-cache --no-root

# production: copy the virtualenv from build and install the current project
FROM python:3.10-slim-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ARG VIRTUAL_ENV_PATH
ENV PATH="$VIRTUAL_ENV_PATH/bin:$PATH"
ENV VIRTUAL_ENV="$VIRTUAL_ENV_PATH"

RUN apt-get update && \
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
