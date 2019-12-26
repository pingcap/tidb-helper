#!/bin/bash

set -e

cd /build/pd && make
cd /build/importer && make release
cd /build/tidb-lightning && make
cd /build/tidb-tools && make build

cp /build/pd/bin/pd-tso-bench /out
cd /build/tidb-lightning/bin && cp tidb-lightning tidb-lightning-ctl /out
cp /build/tidb-tools/bin/sync_diff_inspector  /out
cp /build/importer/target/release/tikv-importer /out