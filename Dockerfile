FROM python:3.11-slim as build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIPENV_VENV_IN_PROJECT=1

RUN apt-get update && apt-get install -y --no-install-recommends \
  gcc \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg2 \
  software-properties-common

# Install Docker to connect to daemon
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt update
RUN apt install -y docker-ce docker-ce-cli containerd.io

WORKDIR /app

RUN pip install --upgrade pipenv
RUN pip install --upgrade pip

# Create user and group "app" and set cache directory for huggingface hub
RUN groupadd -r app && useradd --no-log-init -r -g app app \
    && mkdir -p /app/.cache/huggingface/hub \
    && chown -R app:app /app/.cache/huggingface/hub

COPY Pipfile .
#COPY Pipfile.lock .
RUN pipenv install --verbose --deploy

RUN apt-get install -y netcat-traditional net-tools procps

USER app

FROM build as runtime

ENV HF_HOME=/app/.cache/huggingface/hub

WORKDIR /app

COPY ./opendevin ./opendevin
COPY ./agenthub ./agenthub

# TODO: migrate to use standard .env file
COPY config.toml .

EXPOSE 3000
CMD ["pipenv", "run", "uvicorn", "opendevin.server.listen:app", "--host", "0.0.0.0", "--port", "3000", "--reload"]