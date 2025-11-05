FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y sudo python3  ansible
WORKDIR /root
ENTRYPOINT ["/bin/bash"]