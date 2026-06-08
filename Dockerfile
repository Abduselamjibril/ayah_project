FROM debian:12-slim

# Set non-interactive mode for apt-get
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Install system dependencies with --no-install-recommends
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    ca-certificates \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK (version 3.22.0)
RUN curl -o flutter.tar.xz -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.0-stable.tar.xz \
    && tar -xf flutter.tar.xz -C /opt \
    && rm flutter.tar.xz

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run doctor and pre-download packages
RUN flutter doctor -v

# Copy files using absolute destination
COPY . /app/

# Set working directory to the Flutter app subfolder
WORKDIR /app/quran_app

# Fetch dependencies and run tests to pre-cache everything
RUN flutter pub get

# Command to run tests by default
CMD ["flutter", "test"]
