FROM alpine:3.20
ARG CACHEBUST=1
RUN echo "cachebust=${CACHEBUST}" \
    && apk add --no-cache curl jq bash ca-certificates
WORKDIR /work
COPY seed_test_cases ./seed_test_cases
COPY tests ./tests
