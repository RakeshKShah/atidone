FROM ghcr.io/shopify/toxiproxy:2.9.0
COPY toxiproxy.json /config/toxiproxy.json
CMD ["-host", "0.0.0.0", "-config", "/config/toxiproxy.json"]
