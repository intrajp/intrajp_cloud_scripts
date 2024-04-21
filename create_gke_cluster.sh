###
## Delete all the service accounts on the project.
## Use service account from centralized service accounts project.
##
## Ensure 'Policy for Disable Cross-Project Service Account Usage' Organization Policy is not enabled on both centralized service account project and the project.
##
## Create a service account on the centralized service accounts project which has 'Kubernetes Engine Admin' role.
## Create a user on the project who has 'Monitoring Viewer', 'Logs Viewer', 'Service Account Token Creator' and 'Kubernetes Engine Admin' roles on the project.
## If a user needs to create an alert, add 'Monitoring AlertPolicy Editor'.
## Grant a user to the service account with 'serviceAccountUser' role.
##
## Grant 'service-<PROJECT_NUMBER>@container-engine-robot.iam.gserviceaccount.com' with 'serviceAccountUser' role to the service account.
## Grant '<PROJECT_NUMBER>@cloudservices.gserviceaccount.com' with serviceAccountUser role to the service account.
###
function help()
{
    echo "$ $0 <YOUR PROJECT_ID> <SERVICE_ACCOUNT> <CLUSTER_NAME> <REGION> <ZONE>"
    exit 1
}
## How to use:
##
## $ ./create_gke_cluster.sh <YOUR PROJECT_ID> <SERVICE_ACCOUNT> <CLUSTER_NAME> <REGION> <ZONE>
##
function create_gke_cluster()
{
    PROJECT_ID="${1}"
    if [ -z "${PROJECT_ID}" ]; then
        echo "PROJECT_ID is missing."
	help
    fi
    SERVICE_ACCOUNT="${2}"
    if [ -z "${SERVICE_ACCOUNT}" ]; then
        echo "SERVICE_ACCOUNT is missing."
        help
    fi
    CLUSTER_NAME="${3}"
    if [ -z "${CLUSTER_NAME}" ]; then
        echo "CLUSTER_NAME is missing."
        help
    fi
    REGION="${4}"
    if [ -z "${REGION}" ]; then
        echo "REGION is missing."
        help
    fi
    ZONE="${5}"
    if [ -x "${ZONE}" ]; then
        echo "ZONE is missing."
        help
    fi

    ## Change if you need it.
    RELEASE_CHANNEL="rapid"
    RELEASE_CHANNEL_C="RAPID"
    CLUSTER_VERSION=$(gcloud container get-server-config --flatten="channels" --filter="channels.channel=${RELEASE_CHANNEL_C}" --format="yaml(channels.channel,channels.defaultVersion)" | grep "default" | awk -F":" '{print $2}' | sed -e 's/ //g')
    MACHINE_TYPE="e2-medium"
    NUM_NODES="1"
    DISK_TYPE="pd-balanced"
    DISK_SIZE="100"
    NETWORKS="default"
    DEFAULT_MAX_PODS_PER_NODE="110"
    NODE_LOCATIONS="${ZONE}"
    LOGGING="SYSTEM,WORKLOAD,CONTROLLER_MANAGER,SCHEDULER,API_SERVER"
    MONITORING="SYSTEM,API_SERVER,SCHEDULER,CONTROLLER_MANAGER,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA"
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
    --logging="${LOGGING}" \
    --monitoring="${MONITORING}" \
    --enable-ip-alias \
    --network "projects/${PROJECT_ID}/global/networks/default" \
    --subnetwork "projects/${PROJECT_ID}/regions/${REGION}/subnetworks/default" \
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
}

create_gke_cluster "${1}" "${2}" "${3}" "${4}" "${5}"
