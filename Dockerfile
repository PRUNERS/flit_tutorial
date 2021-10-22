FROM ubuntu:20.04
MAINTAINER mikebentley15@gmail.com

ENV DEBIAN_FRONTEND=noninteractive

# install common build dependencies
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install \
      build-essential \
      coreutils \
      git \
      make \
      sudo \
      && \
    rm -rf /var/lib/apt/lists/*

# create a local non-root user (with sudo access)
RUN groupadd sudo-nopw && \
    useradd \
      --create-home \
      --home-dir /home/flit-user \
      --shell /bin/bash \
      --gid sudo-nopw \
      --groups sudo,dialout \
      flit-user \
      && \
    passwd -d flit-user && \
    echo "%sudo-nopw ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudo-nopw-group

# install FLiT dependencies
RUN apt-get -y update && \
    apt-get -y install \
      binutils \
      python3 \
      python3-pyelftools \
      python3-toml \
      sqlite3 \
      && \
    rm -rf /var/lib/apt/lists/*

# install FLiT
RUN git clone https://github.com/PRUNERS/FLiT /tmp/FLiT && \
    make install -C /tmp/FLiT PREFIX=/usr && \
    rm -rf /tmp/FLiT

# install needed versions specific to these tutorial examples
RUN apt-get -y update && \
    apt-get -y install \
      clang-6.0 \
      cmake \
      diffutils \
      g++-7 \
      libmpich-dev \
      mpich \
      python3-pygments \
      sqlite3 \
      wget \
      && \
    rm -rf /var/lib/apt/lists/*

# install user tools to make this container nicer to use
RUN apt-get -y update && \
    apt-get -y install \
      bash-completion \
      bsdmainutils \
      emacs \
      man \
      tree \
      vim \
      && \
    rm -rf /var/lib/apt/lists/*

USER flit-user
WORKDIR /home/flit-user

# clone copy of FLiT into home directory
RUN mkdir -p src && \
    git clone https://github.com/PRUNERS/FLiT src/FLiT

# clone the tutorial contents and set them up
RUN git clone https://github.com/PRUNERS/flit_tutorial && \
    cd flit_tutorial && \
    bash setup.sh

COPY Dockerfile Dockerfile.flit_tutorial
CMD ["bash"]
