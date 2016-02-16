# VERSION:        0.1
# DESCRIPTION:    Image to build N1 and create a .deb and .rpm file for 32-bit systems, derived from Atom's Dockerfile

# Base docker image
FROM 32bit/ubuntu:14.04

# Force noninteractive mode
ENV DEBIAN_FRONTEND noninteractive

# Setup NodeSource repository for Node LTS v4.x
RUN apt-get update && apt-get install -y curl
RUN curl -sL https://deb.nodesource.com/setup_4.x | bash -

# Correct errors with libpam-systemd (indirect dependency of libnotify4)
RUN /bin/ln -sf /bin/true /sbin/initctl
RUN /usr/bin/touch /etc/init.d/systemd-logind

# Install dependencies (NodeSource setup runs `apt-get update` for us)
RUN apt-get -y install \
    build-essential \
    fakeroot \
    git \
    python \
    rpm \
    nodejs

# For when Linux testing is re-enabled
#    libgconf2-4 \
#    libgnome-keyring-dev \
#    libgtk2.0-0 \
#    libnotify4 \
#    xvfb

#RUN npm install -g npm@3.3.10 --loglevel error

ADD . /n1
WORKDIR /n1
