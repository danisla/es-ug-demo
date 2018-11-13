# Elastic User Group GCP Demo

## Helm and Regional Persistent Disks

1. Deploy Elasticsearch to GKE using Helm chart and Regional PD StorageClass
2. Load dataset
3. Simulate zonal outage

## Elasticserach Operator and Stackdriver export

1. Deploy the elasticsearch-operator
2. Create cluster with operator
3. Export GKE logs from stackdriver to elasticsearch
4. View logs in Kibana

## Bigquery to Logstash

1. Demo how to export data from BQ to logstash
2. Load data from logstash to Elasticsearch
3. View data in Kibana