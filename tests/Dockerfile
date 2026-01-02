FROM python:3.11-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y ffmpeg && rm -rf /var/lib/apt/lists/*
RUN pip install websockets requests trio


# Copy test script and samples
COPY tests /app/tests

# Set the working directory to the tests folder so it finds samples easily
WORKDIR /app/tests

# Default command runs the test
CMD ["python", "e2e_speech_flow.py"]
