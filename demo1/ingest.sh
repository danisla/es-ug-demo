#!/usr/bin/env bash

set -e

ES_HOST=${1:-localhost}

kubectl run es-demo-ingest -i --rm --restart=Never --env ES_HOST=${ES_HOST} --command sh --image alpine:3.8 -- -c '

apk add -u curl ca-certificates gzip

# From: https://www.elastic.co/guide/en/kibana/current/tutorial-load-dataset.html
curl -L https://download.elastic.co/demos/kibana/gettingstarted/logs.jsonl.gz | gunzip > logs.jsonl

for d in 2015.05.18 2015.05.19 2015.05.20
do
    curl -XPUT -H "Content-Type: application/json" http://${ES_HOST}:9200/logstash-${d} -d @- <<EOF
{
  "settings" : {
    "index" : {
      "number_of_shards" : 3, 
      "number_of_replicas" : 3
    }
  },
  "mappings": {
    "log": {
      "properties": {
        "geo": {
          "properties": {
            "coordinates": {
              "type": "geo_point"
            }
          }
        }
      }
    }
  }
}
EOF
done

curl -H "Content-Type: application/x-ndjson" -XPOST "http://${ES_HOST}:9200/_bulk?pretty" --data-binary @logs.jsonl >/dev/null

echo "INFO: Ingest complete!"
'