# Deploying Elasticsearch with Helm and Regional Persistent Disks

[![button](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/kubernetes/?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2Fdanisla%2Fes-ug-demo.git&amp;cloudshell_working_dir=demo1&amp;cloudshell_image=gcr.io%2Fcloud-solutions-group%2Fterraform-helm%3Alatest&amp;cloudshell_tutorial=.%2FREADME.md)

Goals:

1. Deploy Elasticsearch to GKE using Helm chart and Regional PD StorageClass
2. Load dataset
3. Simulate zonal outage

## Custer Setup

1. Create regional cluster:

```bash
CLUSTER_NAME=es-ug-demo
REGION=us-west1
ZONES=us-west1-b,us-west1-c
CLUSTER_VERSION=$(gcloud container get-server-config --region ${REGION} --format='value(validMasterVersions[0])')
gcloud container clusters create ${CLUSTER_NAME} \
  --region ${REGION} \
  --node-locations=${ZONES} \
  --cluster-version=${CLUSTER_VERSION} \
  --machine-type=n1-standard-4 \
  --num-nodes=2 \
  --scopes=cloud-platform
```

2. Get credentials:

```bash
gcloud container clusters get-credentials --region us-west1 es-ug-demo
```

## Regional PD Storage Class

1. Create the storage class for `us-west1-b` and `us-west1-c`:

```bash
kubectl apply -f storageclass.yaml
```

## Deploy Elasticsearch

1. Install tiller:

```bash
kubectl create clusterrolebinding default-admin --clusterrole=cluster-admin --user=$(gcloud config get-value account);
kubectl create serviceaccount tiller --namespace kube-system;
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller;
helm init --service-account=tiller;
until ( helm version --tiller-connection-timeout=1 > /dev/null 2>&1 ); do
    echo "Waiting for tiller install...";
    sleep 2;
done;
echo "Helm install complete";
helm version
```

2. Deploy Elasticsearch with Helm:

```bash
STORAGE_CLASS=repd-west1-b-c && \
helm install stable/elasticsearch --name es-ug-demo \
  --set data.persistence.storageClass=${STORAGE_CLASS} \
  --set data.persistence.size=100Gi \
  --set data.replicas=2 \
  --set data.heapSize=7680m
```

3. Wait for `es-ug-demo-elasticsearch-data-0` and `es-ug-demo-elasticsearch-data-1` pods to become ready:

```
watch -n 5 kubectl get pod
```

## Deploy Cerebro

1. Deploy Cerebro with Helm:

```bash
helm install stable/cerebro --name cerebro-demo \
  --set config.hosts[0].host=http://es-ug-demo-elasticsearch-client:9200,config.hosts[0].name=es-ug-demo
```

2. Open cerebro dashboard:

```bash
export POD_NAME=$(kubectl get pods --namespace default -l "app=cerebro,release=cerebro-demo" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 9000:9000 &
```

3. Click the __Web Preview__ button in Cloud Shell then Change Port to 9000 to open the Cerebro UI.

## Ingest Sample Data

1. Ingest data:

```bash
./ingest.sh es-ug-demo-elasticsearch-client
```

## Simulate Zone Failure