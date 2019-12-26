#!/bin/bash

# TODO: current tidb-binlog depend this env params(master branch already removed),
#  so we should remove this once tidb-binlog not depend on this anymore
GOPATH=$(go env GOPATH)

set -e

cd /build/tidb && make
cd /build/tidb-ctl && make
cd /build/pd && make
cd /build/tikv && make dist_release
cd /build/tidb-binlog && GOPATH=$GOPATH make

cd /build/tidb/bin && cp tidb-server /out
cp /build/tidb-ctl/tidb-ctl /out
cd /build/tikv/bin && cp tikv-server tikv-ctl /out
cd /build/pd/bin && cp pd-server pd-ctl pd-recover /out
cd /build/tidb-binlog/bin && cp arbiter binlogctl drainer pump reparo /out