# Build stage using Red Hat UBI with Python 3.11
FROM registry.access.redhat.com/ubi9/python-311 AS builder

# Install uv for dependency management
USER root
RUN dnf install -y wget && \
    wget -qO- https://astral.sh/uv/install.sh | sh && \
    mv /opt/app-root/src/.local/bin/uv /usr/local/bin/uv && \
    mv /opt/app-root/src/.local/bin/uvx /usr/local/bin/uvx && \
    dnf clean all

# Install the project into `/app`
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Copy dependency files first for better layer caching
COPY pyproject.toml README.md ./

# Generate proper TOML lockfile
RUN uv lock

# Install the project's dependencies using the lockfile
RUN uv sync --frozen --no-install-project --no-dev --no-editable

# Then, add the rest of the project source code and install it
COPY . /app
RUN uv sync --frozen --no-dev --no-editable

# Remove unnecessary files from the virtual environment before copying
RUN find /app/.venv -name '__pycache__' -type d -exec rm -rf {} + && \
    find /app/.venv -name '*.pyc' -delete && \
    find /app/.venv -name '*.pyo' -delete && \
    echo "Cleaned up .venv"

# Final stage using Red Hat UBI minimal
FROM registry.access.redhat.com/ubi9/ubi-minimal

# Install Python runtime in minimal UBI
RUN microdnf install -y python3.11 python3.11-pip && \
    microdnf clean all

# Create a non-root user 'app'
RUN useradd -r -d /home/app -s /bin/bash app && \
    mkdir -p /home/app && \
    chown app:app /home/app
WORKDIR /app
USER app

COPY --from=builder --chown=app:app /app/.venv /app/.venv

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# For minimal OAuth setup without environment variables, use:
# docker run -e ATLASSIAN_OAUTH_ENABLE=true -p 8000:8000 your-image
# Then provide authentication via headers:
# Authorization: Bearer <your_oauth_token>
# X-Atlassian-Cloud-Id: <your_cloud_id>

ENTRYPOINT ["mcp-atlassian"]
