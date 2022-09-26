# vim: filetype=dockerfile
# The virtual env _must_ be installed at the same path across images
# so use a variable to track this
ARG VIRTUAL_ENV_PATH="/opt/venv"

# build stage: build wheels for all dependencies and poetry
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
    pip install --progress-bar off --no-cache \
        'poetry>=1.2.0' \
        setuptools \
        wheel

COPY pyproject.toml poetry.lock ./
RUN poetry export \
       --with dev \
       --format requirements.txt \
       --output requirements.txt && \
    pip wheel \
        --no-deps \
        --progress-bar off \
        --no-cache \
        --requirement requirements.txt \
        --wheel-dir /wheels && \
    rm --recursive requirements.txt

# production: copy the wheels from the build stage, install them all
# then install the current project
FROM python:3.10-slim-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        libpcre3; \
    rm --recursive --force /var/lib/apt/lists/*; \
    useradd --user-group --create-home --shell /bin/bash user

ENV VIRTUAL_ENV=/home/user/venv
ENV PATH="/home/user/venv/bin:$PATH"

COPY --chown=user:user --from=build /wheels /wheels

RUN python -m venv "$VIRTUAL_ENV"; \
    pip install --progress-bar off --no-cache \
        # manually install poetry, since it's not included in the wheels
        poetry \
        /wheels/*.whl && \
    rm --recursive /wheels

COPY --chown=user:user ./ /home/user/proj
WORKDIR /home/user/proj
RUN poetry install --only-root

RUN ["pytest"]
