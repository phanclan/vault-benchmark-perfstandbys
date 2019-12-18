FROM consul:latest
FROM envoyproxy/envoy:v1.8.0
# envoyproxy has no curl
# RUN curl -s -o /tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}+ent/vault_${VAULT_VERSION}+ent_linux_amd64.zip && \
#     unzip -qqo -d /usr/local/bin/ /tmp/vault.zip && \
#     vault -autocomplete-install && \
#     curl -s -o /tmp/consul.zip https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip && \
#     unzip -qqo -d /usr/local/bin/ /tmp/consul.zip && \
#     curl -s -o /tmp/nomad.zip https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/nomad_${NOMAD_VERSION}_linux_amd64.zip && \
#     unzip -qqo -d /usr/local/bin/ /tmp/nomad.zip

COPY --from=0 /bin/consul /bin/consul
ENTRYPOINT ["dumb-init", "consul", "connect", "envoy"]
