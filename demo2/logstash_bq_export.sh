#!/bin/bash

BUCKET=$1

[[ -z "${BUCKET}" ]] && echo "USAGE: $0 <bucket>" && exit 1

function cleanup() {
  kubectl delete pod logstash >/dev/null 2>&1
}
trap cleanup EXIT

echo "INFO: Creating logstash container"

read -r -d '' SCRIPT << EOM
env2yaml /usr/share/logstash/config/logstash.yml

echo "INFO: Installing Google Cloud SDK"
curl -fL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-225.0.0-linux-x86_64.tar.gz | tar zxf -

echo "INFO: Installing GCS plugin"
bin/logstash-plugin install logstash-input-google_cloud_storage logstash-input-exec

cat > logstash.conf <<EOF
input {
  exec {
    command => "/usr/share/logstash/google-cloud-sdk/bin/bq --location=US extract --destination_format=NEWLINE_DELIMITED_JSON 'bigquery-public-data:the_met.objects' 'gs://${BUCKET}/the-met-*.json'"
    interval => 3600
    type => "bq"
  }
}

output { stdout { codec => rubydebug } }
EOF

printf "INFO: Logstash pipeline:\n\n"
cat logstash.conf

printf "\nINFO: Starting logstash"

bin/logstash --debug -f logstash.conf

echo "INFO: Done"
EOM

kubectl run logstash -i --rm --restart=Never --env XPACK_MONITORING_ENABLED=false --command bash --image docker.elastic.co/logstash/logstash:6.2.3 -- -c "${SCRIPT}"