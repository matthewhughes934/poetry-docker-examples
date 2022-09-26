# vim: filetype=dockerfile
FROM python:3.10-slim-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN apt-get update; \
    apt-get install --assume-yes --no-install-recommends \
        # To build C extensions we need a C compiler...
        gcc \
        # and some C library files
        libc-dev \
        # This is an optional extra for building uwsgi
        libpcre3-dev && \
    # following best practices at
    # https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#apt-get
    rm --recursive --force /var/lib/apt/lists/* && \
    useradd --user-group --create-home --shell /bin/bash user

USER user
ENV VIRTUAL_ENV=/home/user/venv
ENV PATH="/home/user/venv/bin:$PATH"

RUN python -m venv /home/user/venv && \
    pip install --progress-bar off --no-cache 'poetry>=1.2.0'

COPY --chown=user:user pyproject.toml poetry.lock /home/user/proj/
WORKDIR /home/user/proj
RUN poetry install --no-cache --no-interaction

COPY . ./
RUN poetry install --only-root

RUN ["pytest"]
