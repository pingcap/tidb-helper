#! /bin/bash

tag=
if [ "$#" -ge "1" ];then
    tag="$1"
fi

# Export to a clean image
cat <<EOT
FROM pingcap/alpine-glibc
COPY build/bin/$tag/* /

EXPOSE 20160 20180

ENTRYPOINT ["/tidb-server"]
EOT
