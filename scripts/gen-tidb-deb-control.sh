#!/bin/sh

# usage: bash gen-deb-control.sh version

if [ "$1" != "" ]; then
  VERSION=$1
else
  VERSION must not be empty!
  exit -1
fi

cat <<-EOF
Package: tidb-toolkit
Version: $VERSION
Section: databases
Priority: optional
Architecture: amd64
Depends: systemd
Maintainer: The TiDB Authors
Description:
 * TiDB-Lightning is a tool for fast full import of large amounts of data into a TiDB cluster. Currently, we support reading SQL dump exported via mydumper.
 * pd-tso-bench is a tool to benchmark GetTS performance.
 * tikv-importer is a front-end to help ingesting large number of KV pairs into a TiKV cluster
 * sync_diff_inspector is a tool for comparing two databases' data and outputting a brief report about the differences.
EOF
