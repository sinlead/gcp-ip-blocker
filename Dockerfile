FROM google/cloud-sdk
LABEL maintainer "Sinlead <opensource@sinlead.com>"
RUN set -ex; \
  apt-get update; \
  apt-get install -qq -y --no-install-recommends ruby; \
  rm -rf /tmp/* /var/lib/apt/lists/*
COPY blocker.rb /opt/sinlead/gcp-ip-blocker/blocker.rb
CMD ["ruby", "/opt/sinlead/gcp-ip-blocker/blocker.rb"]
