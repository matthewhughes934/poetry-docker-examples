# vim: filetype=dockerfile
FROM python:3.10-buster
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

WORKDIR /proj
RUN pip install poetry

COPY pyproject.toml poetry.lock ./

RUN poetry install

COPY . ./
