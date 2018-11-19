#!/bin/bash

BUCKET=${1?"USAGE: $0 <bucket>"}
ES_HOST=${2:-"http://localhost:9200"}

function cleanup() {
  kubectl delete pod logstash >/dev/null 2>&1
}
trap cleanup EXIT

echo "INFO: Creating logstash container"

read -r -d '' SCRIPT << EOM
env2yaml /usr/share/logstash/config/logstash.yml

echo "INFO: Installing GCS plugin"
bin/logstash-plugin install logstash-input-google_cloud_storage logstash-input-exec

cat > logstash.conf <<EOF
input {
  google_cloud_storage {
    interval => 5
    bucket_id => "${BUCKET}"
    codec => "json"
    file_matches => "the-met-.*\.json"
    json_key_file => ""
    delete => false
  }
}

output {
  elasticsearch {
    hosts => ["${ES_HOST}"]
  }
}
EOF

printf "INFO: Logstash pipeline:\n\n"
cat logstash.conf

printf "\nINFO: Starting logstash"

bin/logstash -f logstash.conf

echo "INFO: Done"
EOM

kubectl run logstash -i --rm --restart=Never --env XPACK_MONITORING_ENABLED=false --command bash --image docker.elastic.co/logstash/logstash:6.2.3 -- -c "${SCRIPT}"