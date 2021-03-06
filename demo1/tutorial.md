# Deploying Elasticsearch with Helm and Regional Persistent Disks

[![button](https://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/compute/instanceGroups/?cloudshell_git_repo=https://github.com/danisla/es-ug-demo.git&amp;cloudshell_working_dir=demo1&amp;cloudshell_image=gcr.io/cloud-solutions-group/terraform-helm:latest&amp;cloudshell_tutorial=./tutorial.md)

Goals:

1. Deploy Elasticsearch to GKE using Helm chart and Regional PD StorageClass
2. Load dataset
3. Simulate zonal outage

## Custer Setup

1. Create regional cluster:

```bash
CLUSTER_VERSION=$(gcloud container get-server-config --region us-west1 --format='value(validMasterVersions[0])') && \
gcloud container clusters create es-ug-demo \
  --region us-west1 \
  --cluster-version=${CLUSTER_VERSION} \
  --machine-type=n1-standard-4 \
  --node-labels=es-node=control \
  --num-nodes=1 \
  --scopes=cloud-platform
```

2. Create node pool for data nodes:

```bash
NODE_VERSION=$(gcloud container get-server-config --region us-west1 --format='value(validNodeVersions[0])') && \
gcloud container node-pools create es-data \
  --cluster=es-ug-demo \
  --region=us-west1 \
  --node-version=${NODE_VERSION} \
  --machine-type=n1-highmem-4 \
  --node-labels=es-node=data \
  --num-nodes=2 \
  --scopes=cloud-platform
```

2. Get credentials:

```bash
gcloud container clusters get-credentials --region us-west1 es-ug-demo
```

3. Install tiller:

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
helm repo update;
helm version;
```

## Regional PD Storage Class

1. Create the storage class for `us-west1-b` and `us-west1-c`:

```bash
kubectl apply -f storageclass.yaml
```

## Deploy Elasticsearch

1. Deploy Elasticsearch with Helm:

```bash
helm install stable/elasticsearch --name es-ug-demo \
  --set client.nodeSelector.es-node=control \
  --set master.nodeSelector.es-node=control \
  --set data.nodeSelector.es-node=data \
  --set data.replicas=2 \
  --set data.persistence.size=100Gi \
  --set data.persistence.storageClass=repd-west1-b-c
```

2. Wait for `es-ug-demo-elasticsearch-data-0` and `es-ug-demo-elasticsearch-data-1` pods to become ready:

```bash
watch -n 5 kubectl get pod -o wide
```

## Deploy Cerebro

1. Deploy Cerebro with Helm:

```bash
helm install stable/cerebro --name cerebro-demo \
  --set nodeSelector.es-node=control \
  --set config.hosts[0].host=http://es-ug-demo-elasticsearch-client:9200,config.hosts[0].name=es-ug-demo
```

2. Wait for Cerebro pod:

```bash
watch -n 5 kubectl get pod -o wide
```

3. Open cerebro dashboard:

```bash
POD_NAME=$(kubectl get pods --namespace default -l "app=cerebro,release=cerebro-demo" -o jsonpath="{.items[0].metadata.name}") && \
kubectl port-forward $POD_NAME 8080:9000 >/dev/null &
```

4. Click the __Web Preview__ button in Cloud Shell then Change Port to 8080 to open the Cerebro UI.

## Ingest Sample Data

1. Ingest data:

```bash
./ingest.sh es-ug-demo-elasticsearch-client
```

## Simulate Zone Failure

1. In the Cloud Console, delete all instances for the us-west1-b group.

2. Observe in the Cerebro dashboard that the cluster becomes __RED__ but then after about a minute is green again.

3. Verify that the data node moved to the other replicated zone:

```bash
kubectl get pods -o wide
```

The pod was able to change nodes to a new zone and take the data with it because the persistent disk is being replicated.