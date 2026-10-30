FROM mcr.microsoft.com/devcontainers/python:3.12

ARG OPENTOFU_VERSION=1.11.0
RUN curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.zip" -o /tmp/tofu.zip \
    && unzip -q /tmp/tofu.zip -d /usr/local/bin tofu \
    && chmod +x /usr/local/bin/tofu \
    && rm /tmp/tofu.zip

ARG SOPS_VERSION=3.13.3
RUN curl -fsSL "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" -o /usr/local/bin/sops \
    && chmod +x /usr/local/bin/sops

ARG AGE_VERSION=1.3.2
RUN curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
    | tar xz -C /usr/local/bin age/age age/age-keygen --strip-components=1

ARG K9S_VERSION=0.40.10
RUN curl -fsSL "https://github.com/derailed/k9s/releases/download/v${K9S_VERSION}/k9s_Linux_amd64.tar.gz" \
    | tar xz -C /usr/local/bin k9s

ARG ARGOCD_VERSION=v3.5.6
RUN curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" -o /usr/local/bin/argocd \
    && chmod +x /usr/local/bin/argocd

ARG KUBECONFORM_VERSION=v0.8.0
RUN curl -fsSL "https://github.com/yannh/kubeconform/releases/download/${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz" \
    | tar xz -C /usr/local/bin kubeconform

RUN chown -R vscode:vscode /home/vscode