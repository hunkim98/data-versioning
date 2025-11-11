FROM python:3.11-slim-bookworm

ARG DEBIAN_PACKAGES="build-essential git curl wget unzip gzip"
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV PYENV_SHELL=/bin/bash
ENV PYTHONUNBUFFERED=1
ENV UV_LINK_MODE=copy
ENV UV_PROJECT_ENVIRONMENT=/.venv

# --- Fix Debian invalid GPG signature issue ---
RUN set -eux; \
    # Remove broken lists if they exist
    rm -rf /var/lib/apt/lists/*; \
    # Replace expired Debian keys manually
    mkdir -p /usr/share/keyrings; \
    curl -fsSL https://ftp-master.debian.org/keys/archive-key-12.asc | tee /usr/share/keyrings/debian-archive-key-12.asc > /dev/null; \
    curl -fsSL https://ftp-master.debian.org/keys/archive-key-12-security.asc | tee /usr/share/keyrings/debian-archive-key-12-security.asc > /dev/null; \
    curl -fsSL https://ftp-master.debian.org/keys/archive-key-12-stable.asc | tee /usr/share/keyrings/debian-archive-key-12-stable.asc > /dev/null; \
    echo "deb [signed-by=/usr/share/keyrings/debian-archive-key-12.asc] http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" > /etc/apt/sources.list; \
    echo "deb [signed-by=/usr/share/keyrings/debian-archive-key-12-security.asc] http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" >> /etc/apt/sources.list; \
    echo "deb [signed-by=/usr/share/keyrings/debian-archive-key-12-stable.asc] http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" >> /etc/apt/sources.list; \
    \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        $DEBIAN_PACKAGES \
        lsb-release \
        apt-transport-https \
        software-properties-common \
        openssh-client; \
    \
    # --- Add Google Cloud SDK & GCSFuse repositories securely ---
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | tee /usr/share/keyrings/cloud.google.gpg > /dev/null; \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list; \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt gcsfuse-bionic main" > /etc/apt/sources.list.d/gcsfuse.list; \
    \
    apt-get update && \
    apt-get install -y --no-install-recommends google-cloud-sdk gcsfuse libnss3 libcurl4; \
    \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    \
    pip install --no-cache-dir --upgrade pip && \
    pip install uv && \
    \
    useradd -ms /bin/bash app -d /home/app -u 1000 && \
    mkdir -p /app /.venv /mnt/gcs_data && \
    chown -R app:app /app /.venv /mnt/gcs_data

WORKDIR /app

COPY --chown=app:app pyproject.toml uv.lock* ./
RUN uv sync --frozen
COPY --chown=app:app . ./

ENTRYPOINT ["/bin/bash", "./docker-entrypoint.sh"]