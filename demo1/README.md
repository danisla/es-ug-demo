# Deploying Elasticsearch with Helm and Regional Persistent Disks

[![button](http://gstatic.com/cloudssh/images/open-btn.png)](https://console.cloud.google.com/kubernetes/open?cloudshell_git_repo=https%3A%2F%2Fgithub.com%2Fdanisla%2Fes-ug-demo.git&amp;cloudshell_working_dir=demo1&amp;cloudshell_image=gcr.io%2Fcloud-solutions-group%2Fterraform-helm%3Alatest&amp;cloudshell_tutorial=.%2FREADME.md)

Goals:

1. Deploy Elasticsearch to GKE using Helm chart and Regional PD StorageClass
2. Load dataset
3. Simulate zonal outage

## Setup

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

2. Create the storage class for `us-west1-b` and `us-west1-c`:

```bash
kubectl apply -f - <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: repd-west1-b-c
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: regional-pd
  zones: us-west1-b, us-west1-c
EOF
```

3. Install helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

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

3. Deploy Elasticsearch with Helm:

```bash
STORAGE_CLASS=repd-west1-b-c
helm install stable/elasticsearch --name es-ug-demo \
  --set data.persistence.storageClass=${STORAGE_CLASS} \
  --set data.persistence.size=100Gi \
  --set data.replicas=2 \
  --set data.heapSize=7680m
```

4. Deploy Cerebro with Helm:

```bash
helm install stable/cerebro --name cerebro-demo \
  --set config.hosts[0].host=http://es-ug-demo-elasticsearch-client:9200,config.hosts[0].name=es-ug-demo
```

5. Open cerebro dashboard:

```bash
export POD_NAME=$(kubectl get pods --namespace default -l "app=cerebro,release=cerebro-demo" -o jsonpath="{.items[0].metadata.name}")
echo "Visit http://127.0.0.1:9000 to use your application"
kubectl port-forward $POD_NAME 9000:9000
```

6. Ingest data:

```bash
./ingest.sh es-ug-demo-elasticsearch-client
```

7. Get the name of the instance group for the pod:

```bash
NODE=$(kubectl get pods -l app=elasticsearch,component=data -o jsonpath='{.items[0].spec.nodeName}')

ZONE=$(kubectl get node $NODE -o jsonpath="{.metadata.labels['failure-domain\.beta\.kubernetes\.io/zone']}")

IG=$(gcloud compute instance-groups list --filter="name~gke-.*-default-pool zone:(${ZONE})" --format='value(name)')

echo "Pod is currently on node ${NODE}"

echo "Instance group to delete: ${IG} for zone: ${ZONE}"
```

8. Delete the instance group:

```bash
gcloud compute instance-groups managed delete ${IG} --zone ${ZONE}
```