FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    sudo bash-completion \
    python3 python3-pip \
    jq wget curl vim git \
    net-tools iputils-ping dnsutils \
    iproute2 gpg \
    unzip \
    openssh-server && \
    mkdir -p /var/run/sshd && \
    mkdir -p /etc/ssh && \
    ssh-keygen -A

RUN curl -sSLf https://get.openziti.io/tun/package-repos.gpg | sudo gpg --dearmor --output /usr/share/keyrings/openziti.gpg && \
    sudo chmod a+r /usr/share/keyrings/openziti.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/openziti.gpg] https://packages.openziti.org/zitipax-openziti-deb-stable debian main" | \
    sudo tee /etc/apt/sources.list.d/openziti-release.list >/dev/null

RUN apt-get update && apt-get install -y \
    openziti-controller && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 2171 -s /bin/bash -G sudo ziti && \
    echo 'ziti ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ziti

RUN sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#LoginGraceTime.*/LoginGraceTime 30s/' /etc/ssh/sshd_config && \
    sed -i 's/^#MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config && \
    sed -i 's/^#AllowTcpForwarding.*/AllowTcpForwarding no/' /etc/ssh/sshd_config && \
    sed -i 's/^#AllowAgentForwarding.*/AllowAgentForwarding no/' /etc/ssh/sshd_config && \
    sed -i 's/^X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config

USER ziti

WORKDIR /home/ziti

CMD ["sudo", "/usr/sbin/sshd", "-D"]