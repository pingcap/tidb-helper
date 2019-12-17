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

tag=
if [ "$#" -ge "1" ];then
    tag="$1"
fi

cat <<EOT
FROM centos:7.6.1810 as builder
RUN yum clean all && \
    yum makecache && \
    yum update -y && \
    yum install -y epel-release
EOT

# Install the system dependencies
# Attempt to clean and rebuild the cache to avoid 404s
cat <<EOT
RUN yum clean all && \
    yum makecache && \
	yum update -y && \
	yum install -y tar wget git which file unzip python-pip openssl-devel \
		make cmake3 gcc gcc-c++ libstdc++-static pkg-config psmisc gdb \
		libdwarf-devel elfutils-libelf-devel elfutils-devel binutils-devel \
        dwz && \
	yum clean all
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
RUN wget https://dl.google.com/go/go1.13.5.linux-amd64.tar.gz
RUN tar -xf go1.13.5.linux-amd64.tar.gz
RUN mv go /usr/local
ENV PATH /usr/local/go/bin:\$PATH
ENV GOROOT /usr/local/go
RUN rm -f go1.13.5.linux-amd64.tar.gz
EOT

# Install Rustup
cat <<EOT
RUN curl https://sh.rustup.rs -sSf | sh -s -- --no-modify-path --default-toolchain none -y
ENV PATH /root/.cargo/bin/:\$PATH
EOT

cat << EOT
COPY build /build
EOT

# Install the Rust toolchain
cat <<EOT
RUN rustup self update
RUN rustup set profile minimal
RUN rustup default \$(cat /build/tikv/rust-toolchain)
EOT

# make TiDB
cat << EOT
WORKDIR /build/tidb
EOT

if [ "$tag" != "" ];then
  cat << EOT
RUN git fetch && git checkout v$tag
EOT
fi

cat << EOT
RUN echo TiDB commit: \$(git rev-parse HEAD)
RUN make
RUN cd ..
EOT

# make pd
cat << EOT
WORKDIR /build/pd
EOT

if [ "$tag" != "" ];then
  cat << EOT
RUN git fetch && git checkout v$tag
EOT
fi

cat << EOT
RUN echo pd commit: \$(git rev-parse HEAD)
RUN make
EOT

# make tikv
cat << EOT
WORKDIR /build/tikv
EOT

if [ "$tag" != "" ];then
  cat << EOT
RUN git fetch && git checkout v$tag
EOT
fi

cat << EOT
RUN echo TiKV commit: \$(git rev-parse HEAD)
RUN make dist_release
EOT

# FIXME, compress tikv-server/tikv-ctl, we should do this at `make dist_release` in tikv
# but currently the releases branches doesnot contain these procedures
cat << EOT
RUN objcopy --compress-debug-sections=zlib-gnu /build/tikv/bin/tikv-server
RUN objcopy --compress-debug-sections=zlib-gnu /build/tikv/bin/tikv-ctl
EOT

# Export to a clean image
cat <<EOT
FROM pingcap/alpine-glibc
COPY --from=builder /build/tidb/bin/* /
COPY --from=builder /build/tikv/bin/* /
COPY --from=builder /build/pd/bin/* /

EXPOSE 20160 20180

ENTRYPOINT ["/tidb-server"]
EOT
