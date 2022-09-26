# vim: filetype=dockerfile
FROM python:3.10-buster AS production
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN useradd --user-group --create-home --shell /bin/bash user

USER user
ENV VIRTUAL_ENV=/home/user/venv
ENV PATH="/home/user/venv/bin:$PATH"

RUN python -m venv /home/user/venv && \
    # No progress bar just to make output a bit cleaner in CI
    # no cache to save some space: use docker's caching to avoid re-installs
    pip install --progress-bar off --no-cache 'poetry>=1.2.0'

# COPY before WORKDIR since otherwise WORKDIR will create
# /home/user/proj with ownership root:root
COPY --chown=user:user pyproject.toml poetry.lock /home/user/proj/
WORKDIR /home/user/proj
RUN poetry install --no-cache --no-interaction --no-root

COPY . ./
# install the current project
RUN poetry install --only-root

RUN ["pytest"]
