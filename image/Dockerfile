FROM fedora:32

RUN dnf install -y \
  strace \
  bind-utils \
  httpie \
  mtr \
  iproute \
  tcpdump \
  rsync \
  wireshark-cli \
  procps-ng \
  tar

COPY dns-gather-tool.sh /usr/bin/
CMD /usr/bin/dns-gather-tool.sh
