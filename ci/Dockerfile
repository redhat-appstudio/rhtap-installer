FROM registry.access.redhat.com/ubi9/nodejs-20:latest

ENV SHELLCHECK_VERSION=0.7.1
ENV YQ_VERSION=v4.25.2
ENV TEKTONCD_CLI_VERSION="v0.33.0"

USER root

# hadolint ignore=DL3041
RUN dnf install -y -q --allowerasing --nobest nodejs-devel nodejs-libs python3-pip jq \
    openssl openssl-devel ca-certificates make cmake cpp gcc gcc-c++ zlib zlib-devel brotli brotli-devel python3 nodejs-packaging && \
    pip3 install --upgrade pip && \
    pip3 install --upgrade setuptools && \
    pip3 install yq && \
    dnf update -y && dnf clean all && \
    npm install -g yarn@1.22 npm@9 && \
    echo -n "node version: "; node -v; \
    echo -n "npm  version: "; npm -v; \
    echo -n "yarn version: "; yarn -v && \
    curl --fail -sSL  https://github.com/koalaman/shellcheck/releases/download/v$SHELLCHECK_VERSION/shellcheck-v$SHELLCHECK_VERSION.linux.x86_64.tar.xz | tar -xJvf - shellcheck-v$SHELLCHECK_VERSION/shellcheck && \
    mv shellcheck-v$SHELLCHECK_VERSION/shellcheck /usr/local/bin/shellcheck && chmod 755 /usr/local/bin/shellcheck && rm -rf "shellcheck-v$SHELLCHECK_VERSION" && \
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && chmod 700 get_helm.sh && ./get_helm.sh && rm -rf get_helm.sh && \
    curl -Lso /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 && chmod +x /usr/local/bin/yq && \
    curl -fsSL -o tkn.tgz "https://github.com/tektoncd/cli/releases/download/${TEKTONCD_CLI_VERSION}/tkn_${TEKTONCD_CLI_VERSION:1}_Linux_x86_64.tar.gz" && tar -C "/usr/local/bin" --no-same-owner -xzf "tkn.tgz" tkn && rm -rf "tkn.tgz"
