FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y sudo python3  ansible && ansible-galaxy collection install community.postgresql
WORKDIR /root
CMD ["/bin/bash"]