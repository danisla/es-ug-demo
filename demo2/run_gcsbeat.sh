#!/bin/bash

read -r -d '' SCRIPT << EOM
set -x

curl -L https://github.com/GoogleCloudPlatform/gcsbeat/releases/download/v1.1.0/gcsbeat-linux-amd64.tar.gz | tar zxvf -

cd gcsbeat-linux-amd64
mkdir -p logs
touch logs/gcsbeat
tail -n0 -F logs/* &
chown root:root gcsbeat.yml

./gcsbeat run \
    -E output.elasticsearch.hosts="[es-ug-demo-elasticsearch-client:9200]" \
    -E gcsbeat.bucket_id="disla-goog-com-csa-ext-es-demo" \
    -E gcsbeat.json_key_file="" \
    -E gcsbeat.file_matches="the-met-*.json" \
    -E gcsbeat.codec="json-stream" \
    -E logging.level=info
EOM

kubectl run gcsbeat -it --rm --restart=Never --command bash --image centos:latest -- -c "${SCRIPT}"