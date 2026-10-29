# syntax=docker/dockerfile:1

# Global build argument (must be declared before the first FROM to be usable in FROM lines)
ARG distro=stable-slim

# --- Stage 1: build the web UI with the multi-select patch applied ---
# The patch (webui-multiselect.patch) was made against this exact upstream commit.
FROM node:22-bookworm-slim AS webui-build
ARG webui_repo="https://github.com/airdcpp-web/airdcpp-webui.git"
ARG webui_ref="eeeea5025a5e720f38dac53ced8e002940f00a74"

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /webui
RUN git init -q . \
    && git remote add origin ${webui_repo} \
    && git fetch -q --depth 1 origin ${webui_ref} \
    && git checkout -q FETCH_HEAD

COPY webui-multiselect.patch /tmp/webui-multiselect.patch
RUN git apply --check /tmp/webui-multiselect.patch \
    && git apply /tmp/webui-multiselect.patch

RUN npm ci --no-audit --no-fund \
    && npm run build-webpack

# --- Stage 2: the regular image ---
FROM debian:${distro}

ARG dl_url="https://web-builds.airdcpp.net/develop/airdcpp_latest_develop_64-bit_portable.tar.gz"

RUN installDeps=' \
        curl \
        gnupg \
    ' \
    && runtimeDeps=' \
        ca-certificates \
        locales \
        openssl \
    ' \
# Install dependencies
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y --no-install-recommends ${installDeps} ${runtimeDeps} \
# Install node.js to enable airdcpp extension support
    && curl -sL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
# Download and install airdcpp
    && echo "Downloading ${dl_url}..." \
    && curl --progress-bar ${dl_url} | tar -xz -C / \
# Cleanup
    && apt-get purge --autoremove -y ${installDeps} \
    && rm -rf /var/lib/apt/lists/*

# Configure locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen && dpkg-reconfigure -f noninteractive locales

# Replace the prebuilt web UI with the patched build (multi-select in filelists).
# Copied over the existing files so that anything else shipped in web-resources is kept.
COPY --from=webui-build /webui/dist/ /airdcpp-webclient/web-resources/

# Create default directories
RUN mkdir -p /.airdcpp /Downloads /Share \
    # Set permission on default directories
    && chmod a+rwX /.airdcpp /Downloads /Share \
    # Create symlink to configuration directory
    && ln -sf /.airdcpp /airdcpp-webclient/config \
    # Fix /favicon.ico 404 request
    && cd /airdcpp-webclient/web-resources \
    && ln -sf images/favicon.*.ico favicon.ico

# Copy dark mode CSS and the injector script, then run it
COPY dark.css /tmp/dark.css
COPY inject-css.js /tmp/inject-css.js
RUN node /tmp/inject-css.js \
    && rm /tmp/dark.css /tmp/inject-css.js

COPY .airdcpp/ /.default-config
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 5600 5601 21248 21249
ENTRYPOINT ["/entrypoint.sh"]
