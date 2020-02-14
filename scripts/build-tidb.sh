#!/bin/bash

# TODO: current tidb-binlog depend this env params(master branch already removed),
#  so we should remove this once tidb-binlog not depend on this anymore
GOPATH=$(go env GOPATH)

set -e

if [ "$SOURCE_DIR" == "" ] || [ ! -d $SOURCE_DIR ]; then
  echo SOURCE_DIR not exist or is not a directory
  exit 1
fi

if [ "$TARGET_DIR" == "" ] || [ ! -d $TARGET_DIR ]; then
  echo TARGET_DIR not exist or is not a directory
  exit 1
fi

cd $SOURCE_DIR/tidb && make
cd $SOURCE_DIR/tidb-ctl && make
cd $SOURCE_DIR/pd && make

if [ "$(uname -m)" = "aarch64" ];then
    cd $SOURCE_DIR/tikv && ROCKSDB_SYS_SSE=0 make dist_release
else
    cd $SOURCE_DIR/tikv && make dist_release
fi

cd $SOURCE_DIR/tidb-binlog && GOPATH=$GOPATH make

cd $SOURCE_DIR/tidb/bin && cp tidb-server $TARGET_DIR
cp $SOURCE_DIR/tidb-ctl/tidb-ctl $TARGET_DIR
cd $SOURCE_DIR/tikv/bin && cp tikv-server tikv-ctl $TARGET_DIR
cd $SOURCE_DIR/pd/bin && cp pd-server pd-ctl pd-recover $TARGET_DIR
cd $SOURCE_DIR/tidb-binlog/bin && cp arbiter binlogctl drainer pump reparo $TARGET_DIR
