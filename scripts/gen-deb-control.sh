#!/bin/sh

# usage: bash gen-deb-control.sh version

if [ "$1" != "" ]; then
  VERSION=$1
else
  VERSION must not be empty!
  exit -1
fi

cat <<-EOF
Package: tidb
Version: $VERSION
Section: databases
Priority: optional
Architecture: amd64
Depends: systemd
Maintainer: The TiDB Authors
Description:
 TiDB is an open-source NewSQL database that supports Hybrid Transactional and Analytical Processing (HTAP) workloads. It is MySQL compatible and features horizontal scalability, strong consistency, and high availability.
 TiDB features:
 * Horizontal Scalability
 * MySQL Compatible Syntax
 * Distributed Transactions with Strong Consistency
 * Cloud Native
 * Minimize ETL
 * High Availability
EOF
