#! /bin/bash
# This Docker image contains a minimal build environment for TiDB & TiKV & pd
#
# It contains all the tools necessary to reproduce official production builds of TiDB & TiKV & pd

# We need to use CentOS 7 because many of our users choose this as their deploy machine.
# Since the glibc it uses (2.17) is from 2012 (https://sourceware.org/glibc/wiki/Glibc%20Timeline)
# it is our lowest common denominator in terms of distro support.
#
# Usage: bash gen-dockerfile.sh [release-tag]
# if release-tag not provided, all the build will base on current master

# We require epel packages, so enable the fedora EPEL repo then install dependencies.

rust_version=
if [ "$#" -ge "1" ];then
    rust_version="$1"
fi

# Make TiDB available on multiple arch
pkg_arch=$2
if [ "$pkg_arch" = "arm64" ];then
  docker_image_name="arm64v8/centos:7"
else
  docker_image_name="centos:7.6.1810"
fi

cat <<EOT
FROM ${docker_image_name} as builder
RUN yum clean all && \
    yum makecache && \
    yum update -y && \
    yum install -y epel-release
EOT

# Install the system dependencies
# Attempt to clean and rebuild the cache to avoid 404s
cat <<EOT
RUN yum install -y tar wget git which file unzip python-pip openssl-devel \
		make cmake3 gcc gcc-c++ libstdc++-static pkg-config psmisc gdb \
		libdwarf-devel elfutils-libelf-devel elfutils-devel binutils-devel \
    dwz
EOT

if [ "$pkg_arch" = "arm64" ];then
  cat <<EOT
RUN yum install -y clang clang-devel
EOT
fi

# Clean YUM Cache
cat <<EOT
RUN yum clean all
EOT

# CentOS gives cmake 3 a weird binary name, so we link it to something more normal
# This is required by many build scripts, including ours.
cat <<EOT
RUN ln -s /usr/bin/cmake3 /usr/bin/cmake
ENV LIBRARY_PATH /usr/local/lib:\$LIBRARY_PATH
ENV LD_LIBRARY_PATH /usr/local/lib:\$LD_LIBRARY_PATH
EOT

# Install golang
cat << EOT
RUN wget https://dl.google.com/go/go1.13.5.linux-${pkg_arch}.tar.gz
RUN tar -xf go1.13.5.linux-${pkg_arch}.tar.gz
RUN mv go /usr/local
ENV PATH /usr/local/go/bin:\$PATH
ENV GOROOT /usr/local/go
RUN rm -f go1.13.5.linux-${pkg_arch}.tar.gz
EOT

# Install Rustup
cat <<EOT
RUN curl https://sh.rustup.rs -sSf | sh -s -- --no-modify-path --default-toolchain none -y
ENV PATH /root/.cargo/bin/:\$PATH
EOT

# Install the Rust toolchain
cat <<EOT
RUN rustup self update
RUN rustup set profile minimal
RUN rustup default $rust_version
EOT


# Export to a clean image
cat <<EOT
EXPOSE 20160 20180

ENTRYPOINT ["bash"]
EOT
