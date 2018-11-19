# BigQuery export and GCS import with Logstash

[![button](https://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/open?cloudshell_git_repo=https://github.com/danisla/es-ug-demo.git&amp;cloudshell_working_dir=demo2&amp;cloudshell_image=gcr.io/cloud-solutions-group/terraform-helm:latest&amp;cloudshell_tutorial=./tutorial.md&open_in_editor=./logstash_gcs_import.sh)

Goals:

1. Export data from BigQuery to GCS using Logstash
2. Import data from GCS to Elasticsearch using Logstash

## Export data from BigQuery to GCS

1. Run script to export data:

```bash
BUCKET=$(gcloud config get-value project)-es-demo;

./logstash_bq_export.sh ${BUCKET}
```

## Import data from GCS to Elasticsearch

1. Run script to import data:

```bash
BUCKET=$(gcloud config get-value project)-es-demo;
ES_HOST=http://es-ug-demo-elasticsearch-client:9200;

./logstash_gcs_import.sh ${BUCKET} ${ES_HOST}
```
