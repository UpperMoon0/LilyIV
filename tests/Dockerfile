FROM python:3.11-slim

# Install dependencies (Matched to Echo/Dockerfile for caching)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y \
    ffmpeg

WORKDIR /app

RUN --mount=type=cache,target=/root/.cache/pip \
    pip install websockets requests trio


# Copy test script and samples
COPY tests /app/tests

# Set the working directory to the tests folder so it finds samples easily
WORKDIR /app/tests

# Default command runs the test
CMD ["python", "e2e_speech_flow.py"]
