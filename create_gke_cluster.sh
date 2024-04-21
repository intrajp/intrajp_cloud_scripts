
###
## Delete all the service accounts on the project.
## Use service account from centralized service accounts project.
##
## Create a service account on the centralized service accounts project and add 'Kubernetes Engine Admin' role.
## Create a user on the project who has 'Monitoring Viewer', 'Logs Viewer', 'Service Account Token Creator' and 'Kubernetes Engine Admin' roles on the project.
## Grant a user to the service account with 'serviceAccountUser' role.
##
## 'service-<PROJECT_NUMBER>@container-engine-robot.iam.gserviceaccount.com' also needs 'serviceAccountUser' role to the service account.
## '<PROJECT_NUMBER>@cloudservices.gserviceaccount.com' also needs serviceAccountUser role to the service account.
###
PROJECT_ID="<YOUR PROJECT ID>"
SERVICE_ACCOUNT="<YOUR_SERVICE_ACCOUNT>"
ZONE="<ZONE>"

## Change if you need it.
RELEASE_CHANNEL="rapid"
RELEASE_CHANNEL_C="RAPID"
CLUSTER_NAME="cluster-6"
CLUSTER_VERSION=$(gcloud container get-server-config --flatten="channels" --filter="channels.channel=${RELEASE_CHANNEL_C}" --format="yaml(channels.channel,channels.defaultVersion)" | grep "default" | awk -F":" '{print $2}' | sed -e 's/ //g')
MACHINE_TYPE="e2-medium"
DISK_TYPE="pd-balanced"
DISK_SIZE="100"
NUM_NODES="3"
NETWORKS="default"
REGION="us-central1"
DEFAULT_MAX_PODS_PER_NODE="110"
NODE_LOCATIONS="us-central1-c"
NUM_NODES="1"
DEFAULT_MAX_PODS_PER_NODE="110"
ADDONS="GcsFuseCsiDriver"
WORKLOAD_POOL="${PROJECT_ID}.svc.id.goog"
## END Change if you need it.

gcloud beta container --project "${PROJECT_ID}" clusters create "${CLUSTER_NAME}" \
--zone="${ZONE}" \
--service-account="${SERVICE_ACCOUNT}" \
--no-enable-basic-auth \
--cluster-version "${CLUSTER_VERSION}" \
--release-channel "${RELEASE_CHANNEL}" \
--machine-type "${MACHINE_TYPE}" \
--image-type "COS_CONTAINERD" \
--disk-type "${DISK_TYPE}" \
--disk-size "${DISK_SIZE}" \
--metadata disable-legacy-endpoints=true \
--scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
--spot \
--num-nodes "${NUM_NODES}" \
--logging=SYSTEM,WORKLOAD,CONTROLLER_MANAGER,SCHEDULER,API_SERVER \
--monitoring=SYSTEM,API_SERVER,SCHEDULER,CONTROLLER_MANAGER,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA \
--enable-ip-alias \
--network "projects/${PROJECT_ID}/global/networks/default" \
--subnetwork "projects/${PROJECT_ID}/regions/us-central1/subnetworks/default" \
--no-enable-intra-node-visibility \
--default-max-pods-per-node "${DEFAULT_MAX_PODS_PER_NODE}" \
--security-posture=standard \
--workload-vulnerability-scanning=standard \
--no-enable-master-authorized-networks \
--addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
--enable-autoupgrade \
--enable-autorepair \
--max-surge-upgrade 1 \
--max-unavailable-upgrade 0 \
--binauthz-evaluation-mode=DISABLED \
--enable-managed-prometheus \
--workload-pool "${WORKLOAD_POOL}" \
--enable-shielded-nodes \
--notification-config=pubsub=ENABLED,pubsub-topic=projects/"${PROJECT_ID}"/topics/kubernetes \
--node-locations "${ZONE}"
