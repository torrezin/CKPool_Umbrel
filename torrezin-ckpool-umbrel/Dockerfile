FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install ALL dependencies including libcap2-bin for setcap
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    autoconf \
    automake \
    libtool \
    pkg-config \
    libjansson-dev \
    libssl-dev \
    libpq-dev \
    postgresql-client \
    yasm \
    python3 \
    libcap2-bin \
    && rm -rf /var/lib/apt/lists/*

# Create ckpool user
RUN useradd -r -s /bin/false ckpool

# Clone and build CKPool
WORKDIR /tmp
RUN git clone https://bitbucket.org/ckolivas/ckpool.git
WORKDIR /tmp/ckpool

# Build CKPool
RUN ./autogen.sh && ./configure && make

# Install manually to avoid setcap issues - skip make install entirely
RUN mkdir -p /usr/local/bin && \
    cp src/ckpool /usr/local/bin/ && \
    cp src/ckpmsg /usr/local/bin/ && \
    cp src/notifier /usr/local/bin/ && \
    chmod +x /usr/local/bin/ckpool /usr/local/bin/ckpmsg /usr/local/bin/notifier

# Create directories with all subdirectories CKPool needs
RUN mkdir -p /var/log/ckpool/users \
             /var/log/ckpool/pool \
             /var/log/ckpool/block \
             /var/log/ckpool/share \
             /var/log/ckpool/auth \
             /etc/ckpool \
             /var/lib/ckpool \
             /tmp/ckpool

# Set proper ownership and permissions
RUN chown -R ckpool:ckpool /var/log/ckpool /var/lib/ckpool /tmp/ckpool && \
    chmod -R 755 /var/log/ckpool /tmp/ckpool

# Copy scripts
COPY entrypoint.sh /usr/local/bin/
COPY healthcheck.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Expose ports
EXPOSE 3333 3334

# Switch to ckpool user
USER ckpool
WORKDIR /var/lib/ckpool

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]