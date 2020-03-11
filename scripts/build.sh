#!/bin/bash

set -e

cd /build/tidb && make
cd /build/pd && make
cd /build/tikv && make dist_release
cd /build/tidb-lightning && make
cd /build/tidb-tools && make build


cd /build/tidb/bin && cp tidb-server /out
cd /build/tikv/bin && cp tikv-server tikv-ctl /out
cd /build/pd/bin && cp pd-server pd-ctl pd-recover pd-tso-bench /out
cd /build/tidb-lightning && cp tidb-lightning tidb-lightning-ctl /out
cd /build/todb-tools/bin && cp /out