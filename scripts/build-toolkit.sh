#!/bin/bash

set -e

if [ "$SOURCE_DIR" == "" ] || [ ! -d $SOURCE_DIR ]; then
  echo SOURCE_DIR not exist or is not a directory
  exit 1
fi

if [ "$TARGET_DIR" == "" ] || [ ! -d $TARGET_DIR ]; then
  echo TARGET_DIR not exist or is not a directory
  exit 1
fi

cd $SOURCE_DIR/pd && make
if [ "$(uname -p)" = "aarch64" ];then
    cd $SOURCE_DIR/importer && ROCKSDB_SYS_SSE=0 make release
else
    cd $SOURCE_DIR/importer && make release
fi
cd $SOURCE_DIR/tidb-lightning && make
cd $SOURCE_DIR/tidb-tools && make build

cp $SOURCE_DIR/pd/bin/pd-tso-bench $TARGET_DIR
cd $SOURCE_DIR/tidb-lightning/bin && cp tidb-lightning tidb-lightning-ctl $TARGET_DIR
cp $SOURCE_DIR/tidb-tools/bin/sync_diff_inspector  $TARGET_DIR
cp $SOURCE_DIR/importer/target/release/tikv-importer $TARGET_DIR
