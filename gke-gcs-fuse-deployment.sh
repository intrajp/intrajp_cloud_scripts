#!/bin/bash
###
## Create fuse csi bucket and use from the deployment in 2 different namespaces.
##
## Caller needs 'storage.admin' role to execute this script.
## Unless you give the caller above role, the container will not be created.
## You need 'add_annotation' function in this script.
## For troubleshoot:
## https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/blob/main/docs/troubleshooting.md
## https://github.com/GoogleCloudPlatform/gcs-fuse-csi-driver/blob/main/docs/authentication.md
###
## Set these.
PROJECT_ID="<PROJECT_ID>"
CLUSTER_NAME="<CLUSTER>"
export BUCKET="<BUCKET>"
## END Set these.

## Change if you need to.
RELEASE_CHANNEL="regular"
RELEASE_CHANNEL_C="REGULAR"
CLUSTER_VERSION=$(gcloud container get-server-config --flatten="channels" --filter="channels.channel=${RELEASE_CHANNEL_C}" --format="yaml(channels.channel,channels.defaultVersion)" | grep "default" | awk -F":" '{print $2    }' | sed -e 's/ //g')
MACHINE_TYPE="e2-medium"
DISK_TYPE="pd-balanced"
DISK_SIZE="100"
NUM_NODES="3"
NETWORKS="default"
REGION="us-central1"
DEFAULT_MAX_PODS_PER_NODE="110"
NODE_LOCATIONS="us-central1-c"
NUM_NODES="1"
ADDONS="GcsFuseCsiDriver"
WORKLOAD_POOL="${PROJECT_ID}.svc.id.goog"
## END Change if you need to.

export NAMESPACE="fuse"
export NAMESPACE_ANOTHER="fuse-another"

KUBERNETES_SERVICE_ACCOUNT="fuse-ksa"
KUBERNETES_SERVICE_ACCOUNT_ANOTHER="fuse-ksa-another"
IAM_SERVICE_ACCOUNT="fuse-app-2"
IAM_SERVICE_ACCOUNT_ANOTHER="fuse-app-another-2"

STORAGE_CLASS_NAME="example-storage-class"
STORAGE_CAPACITY="5Gi"

PERSISTENT_VOLUME="gcs-fuse-csi-pv"
PERSISTENT_VOLUME_ANOTHER="gcs-fuse-csi-pv-another"
PERSISTENT_VOLUME_CLAIM="gcs-fuse-csi-static-pvc"
PERSISTENT_VOLUME_CLAIM_ANOTHER="gcs-fuse-csi-static-pvc-another"

READONLY="false"
ACCESS_MODES="ReadWriteMany"
export POD_NAME="gcs-fuse-csi-example-static-pvc-pod"
FUSE_CONTAINER="fuse-container"
FUSE_CONTAINER_IMAGE="busybox"

## Function

# Describe the project
function describe_project() {
  gcloud compute project-info describe --project "${PROJECT_ID}"
}

# change default zone() {
function change_default_zone() {
  gcloud compute project-info add-metadata \
    --metadata google-compute-default-region="${NODE_LOCATIONS}",google-compute-default-zone="${NODE_LOCATIONS}"
  gcloud init
}

# Set quota project
function set_quota_project() {
  gcloud auth application-default set-quota-project "${PROJECT_ID}"
}

# Set projectid
function set_projectid() {
  gcloud config set project "${$PROJECT_ID}"
}

# Create a bucket
function create_bucket() {
  gsutil ls gs://"${BUCKET}"
  local rst=$(echo $?)
  if [ $rst -eq 1 ]; then
    gcloud storage buckets create gs://"${BUCKET}"
    local rst2=$(echo $?)
    if [ $rst2 -eq 1 ]; then
      echo "I cannot create bucket ${BUCKET}."
      exit 1
    fi
  else
    echo "${BUCKET} exists."
  fi
}
# Create a cluster
function create_cluster() {
  echo "project_id:${PROJECT_ID}"
  echo "cluster_name:${CLUSTER_NAME}"
  echo "cluster_version:${CLUSTER_VERSION}"
  echo "release-channel:${RELEASE_CHANNEL}"
  echo "zone:${NODE_LOCATIONS}"
  echo "num-nodes:${NUM_NODES}"
  echo "addons:${ADDONS}"
  echo "workload-pool:${WORKLOAD_POOL}"
  echo "------"
  gcloud beta container clusters create "${CLUSTER_NAME}" \
    --cluster-version="${CLUSTER_VERSION}" \
    --release-channel="${RELEASE_CHANNEL}" \
    --addons="${ADDONS}" \
    --zone="${NODE_LOCATIONS}" \
    --num-nodes="${NUM_NODES}" \
    --workload-pool="${WORKLOAD_POOL}"
}

# Get credential of the cluster
function get_container_credentials() {
  gcloud container clusters get-credentials "${CLUSTER_NAME}" --zone="${NODE_LOCATIONS}"
  if [ $? -eq 1 ]; then
    exit 1
  fi
}

# Create a namespace
function create_namespace() {
  kubectl create namespace "${NAMESPACE}"
  kubectl create namespace "${NAMESPACE_ANOTHER}"
}

###
# Create kubernetes service account
function create_kubernetes_service_account() {
  kubectl get serviceaccount --namespace "${NAMESPACE}" | grep "${KUBERNETES_SERVICE_ACCOUNT}"
  local rst=$(echo $?)
  if [ $rst -eq 1 ]; then
    kubectl create serviceaccount "${KUBERNETES_SERVICE_ACCOUNT}" \
      --namespace "${NAMESPACE}"
  else
    echo "Kubernetec service account ${KUBERNETES_SERVICE_ACCOUNT} exists."
  fi
}

# Create kubernetes service account another
function create_kubernetes_service_account_another() {
  kubectl get serviceaccount --namespace "${NAMESPACE_ANOTHER}" | grep "${KUBERNETES_SERVICE_ACCOUNT_ANOTHER}"
  local rst=$(echo $?)
  if [ $rst -eq 1 ]; then
    kubectl create serviceaccount "${KUBERNETES_SERVICE_ACCOUNT_ANOTHER}" \
      --namespace "${NAMESPACE_ANOTHER}"
  else
    echo "Kubernetec service account ${KUBERNETES_SERVICE_ACCOUNT_ANOTHER} exists."
  fi
}
###
# Create IAM service account
function create_iam_service_account() {
  gcloud iam service-accounts list | grep "${IAM_SERVICE_ACCOUNT}"
  local rst=$(echo $?)
  if [ $rst -eq 1 ]; then
    gcloud iam service-accounts create "${IAM_SERVICE_ACCOUNT}" \
      --project="${PROJECT_ID}"
  else
    echo "IAM service account ${IAM_SERVICE_ACCOUNT} exists."
  fi
}

# Create IAM service account another
function create_iam_service_account_another() {
  gcloud iam service-accounts list | grep "${IAM_SERVICE_ACCOUNT_ANOTHER}"
  local rst=$(echo $?)
  if [ $rst -eq 1 ]; then
    gcloud iam service-accounts create "${IAM_SERVICE_ACCOUNT_ANOTHER}" \
      --project="${PROJECT_ID}"
  else
    echo "IAM service account ${IAM_SERVICE_ACCOUNT_ANOTHER} exists."
  fi
}
###
# Add a role (roles/storage.admin) to one account
function add_a_role_storage_admin() {
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${IAM_SERVICE_ACCOUNT}@"${PROJECT_ID}".iam.gserviceaccount.com" \
    --role "roles/storage.admin"
}
# Add a role (roles/storage.admin) to another account
function add_a_role_storage_admin_another() {
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${IAM_SERVICE_ACCOUNT_ANOTHER}@"${PROJECT_ID}".iam.gserviceaccount.com" \
    --role "roles/storage.admin"
}
###
# Add a role (roles/logging.logWriter) to one account
function add_a_role_logging_logwriter() {
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${IAM_SERVICE_ACCOUNT}@"${PROJECT_ID}".iam.gserviceaccount.com" \
    --role "roles/logging.logWriter"
}
# Add a role (roles/logging.logWriter) to another account
function add_a_role_logging_logwriter_another() {
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${IAM_SERVICE_ACCOUNT_ANOTHER}@"${PROJECT_ID}".iam.gserviceaccount.com" \
    --role "roles/logging.logWriter"
}
###
# Add a role (roles/monitoring.metricWriter) to one account 
function add_a_role_monitoring_metricwriter() {
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${IAM_SERVICE_ACCOUNT}@"${PROJECT_ID}".iam.gserviceaccount.com" \
    --role "roles/monitoring.metricWriter"
}
# Add a role (roles/monitoring.metricWriter) to another account
function add_a_role_monitoring_metricwriter_another() {
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${IAM_SERVICE_ACCOUNT_ANOTHER}@"${PROJECT_ID}".iam.gserviceaccount.com" \
    --role "roles/monitoring.metricWriter"
}
###
# Add IAM policy binding between 2 service accounts
function add_iam_policy_binding_between_two_service_accounts (){
  gcloud iam service-accounts add-iam-policy-binding "${IAM_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${KUBERNETES_SERVICE_ACCOUNT}]"
}
# Add IAM policy binding between 2 service accounts
function add_iam_policy_binding_between_two_service_accounts_another (){
  gcloud iam service-accounts add-iam-policy-binding "${IAM_SERVICE_ACCOUNT_ANOTHER}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE_ANOTHER}/${KUBERNETES_SERVICE_ACCOUNT_ANOTHER}]"
}
###
# Add annotation to one account
function add_annotation() {
  kubectl annotate serviceaccount "${KUBERNETES_SERVICE_ACCOUNT}" \
    --namespace ${NAMESPACE} \
    "iam.gke.io/gcp-service-account=${IAM_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
}
# Add annotation to another account
function add_annotation_another() {
  kubectl annotate serviceaccount "${KUBERNETES_SERVICE_ACCOUNT_ANOTHER}" \
    --namespace ${NAMESPACE_ANOTHER} \
    "iam.gke.io/gcp-service-account=${IAM_SERVICE_ACCOUNT_ANOTHER}@${PROJECT_ID}.iam.gserviceaccount.com"
}
###

# Create a test Pod (just for a test and does not have a controller)
function create_test_pod() {
cat << EOF  | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: workload-identity-test
  namespace: "${NAMESPACE}"
spec:
  containers:
  - image: google/cloud-sdk:slim
    name: workload-identity-test
    command: ["sleep","infinity"]
  serviceAccountName: ${KUBERNETES_SERVICE_ACCOUNT}
  nodeSelector:
    iam.gke.io/gke-metadata-server-enabled: "true"
EOF
}

# Create Persistent Volume
function create_persistent_volume() {
cat << EOF  | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: "${PERSISTENT_VOLUME}"
spec:
  accessModes:
  - "${ACCESS_MODES}"
  capacity:
    storage: "${STORAGE_CAPACITY}"
  storageClassName: "${STORAGE_CLASS_NAME}"
  claimRef:
    namespace: "${NAMESPACE}"
    name: "${PERSISTENT_VOLUME_CLAIM}"
  mountOptions:
    - implicit-dirs
  csi:
    driver: gcsfuse.csi.storage.gke.io
    volumeHandle: "${BUCKET}"
    readOnly: $READONLY
EOF
}

# Create Persistent Volume another
function create_persistent_volume_another() {
cat << EOF  | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: "${PERSISTENT_VOLUME_ANOTHER}"
spec:
  accessModes:
  - "${ACCESS_MODES}"
  capacity:
    storage: "${STORAGE_CAPACITY}"
  storageClassName: "${STORAGE_CLASS_NAME}"
  claimRef:
    namespace: "${NAMESPACE_ANOTHER}"
    name: "${PERSISTENT_VOLUME_CLAIM_ANOTHER}"
  mountOptions:
    - implicit-dirs
  csi:
    driver: gcsfuse.csi.storage.gke.io
    volumeHandle: "${BUCKET}"
    readOnly: $READONLY
EOF
}

# Create Persistent Volume Claim
function create_persistent_volume_claim() {
cat << EOF  | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: "${PERSISTENT_VOLUME_CLAIM}"
  namespace: "${NAMESPACE}"
spec:
  accessModes:
  - "${ACCESS_MODES}"
  resources:
    requests:
      storage: "${STORAGE_CAPACITY}"
  volumeName: "${PERSISTENT_VOLUME}"
  storageClassName: "${STORAGE_CLASS_NAME}"
EOF
}

# Create Persistent Volume Claim another
function create_persistent_volume_claim_another() {
cat << EOF  | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: "${PERSISTENT_VOLUME_CLAIM_ANOTHER}"
  namespace: "${NAMESPACE_ANOTHER}"
spec:
  accessModes:
  - "${ACCESS_MODES}"
  resources:
    requests:
      storage: "${STORAGE_CAPACITY}"
  volumeName: "${PERSISTENT_VOLUME_ANOTHER}"
  storageClassName: "${STORAGE_CLASS_NAME}"
EOF
}

# Create Pod(s)
function create_pod() {
cat << EOF  | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: "${POD_NAME}"
  namespace: "${NAMESPACE}"
  annotations:
    gke-gcsfuse/volumes: "true"
    gke-gcsfuse/cpu-limit: 20m
    gke-gcsfuse/memory-limit: 200Mi
    gke-gcsfuse/cpu-request: 10m
    gke-gcsfuse/memory-request: 100Mi
    gke-gcsfuse/ephemeral-storage-limit: "${STORAGE_CAPACITY}"
spec:
  securityContext:
    runAsUser: 1001
    runAsGroup: 2002
    fsGroup: 3003
  containers:
  - image: "${FUSE_CONTAINER_IMAGE}"
    name: "${FUSE_CONTAINER}"
    command: ["sleep"]
    args: ["infinity"]
    volumeMounts:
    - name: gcs-fuse-csi-static
      mountPath: /data
      readOnly: $READONLY
  serviceAccountName: "${KUBERNETES_SERVICE_ACCOUNT}"
  volumes:
  - name: gcs-fuse-csi-static
    persistentVolumeClaim:
      claimName: "${PERSISTENT_VOLUME_CLAIM}"
      readOnly: $READONLY
EOF
}

# delete the pod
function delete_pod() {
  local pod_name="${1}"
  local namespace="${2}"
  echo "I will delete ${pod_name} in ${namespace}"
  kubectl delete pod "${pod_name}" --namespace "${namespace}"
}

# Check fuse
function check_fuse() {
  # Check everything worked fine.
  # Wait 5 minutes and type these commands
  gsutil ls gs://"${BUCKET}"
  echo "------"
  echo " I wll Wait 5 minutes and type these commands."
  echo " So, please wait 5 minutes until you get prompt of the ${POD_NAME}."
  echo "# Please check executing these commands in ${POD_NAME}."
  echo "$ ls /"
  echo "$ cd /data"
  echo "$ touch test1.txt"
  echo "$ exit"
  echo "# After you exit from ${POD_NAME}, please also check inside of the bucket."
  echo "$  gsutil ls gs://${BUCKET}"
  sleep 300
  kubectl exec -it "${POD_NAME}" -n "${NAMESPACE}" -c "${FUSE_CONTAINER}" -- ash
}

# create deployment and try to use PV in original namespace (which is OK)
function create_deployment_in_original_namespace() {
cat << EOF  | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: "${NAMESPACE}"
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        gke-gcsfuse/volumes: "true"
        gke-gcsfuse/cpu-limit: 400m
        gke-gcsfuse/memory-limit: 800Mi
        gke-gcsfuse/cpu-request: 200m
        gke-gcsfuse/memory-request: 400Mi
        gke-gcsfuse/ephemeral-storage-limit: "${STORAGE_CAPACITY}"
    spec:
      containers:
        - name: nginx
          image: nginx:1.14.2
          ports:
          - containerPort: 80
          volumeMounts:
            #- mountPath: "/usr/share/nginx/html"
            - mountPath: "/data"
              name: gcs-fuse-csi-static
      serviceAccountName: "${KUBERNETES_SERVICE_ACCOUNT}"
      volumes:
      - name: gcs-fuse-csi-static
        persistentVolumeClaim:
          claimName: "${PERSISTENT_VOLUME_CLAIM}"
          readOnly: $READONLY
EOF
}

# create deployment and try to use PV in another namespace
function create_deployment_in_another_namespace() {
cat << EOF  | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: "${NAMESPACE_ANOTHER}"
  labels:
    app: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
      annotations:
        gke-gcsfuse/volumes: "true"
        gke-gcsfuse/cpu-limit: 400m
        gke-gcsfuse/memory-limit: 800Mi
        gke-gcsfuse/cpu-request: 200m
        gke-gcsfuse/memory-request: 400Mi
        gke-gcsfuse/ephemeral-storage-limit: "${STORAGE_CAPACITY}"
    spec:
      containers:
        - name: nginx
          image: nginx:1.14.2
          ports:
          - containerPort: 80
          volumeMounts:
            #- mountPath: "/usr/share/nginx/html"
            - mountPath: "/data"
              name: gcs-fuse-csi-static-another
      serviceAccountName: "${KUBERNETES_SERVICE_ACCOUNT_ANOTHER}"
      volumes:
      - name: gcs-fuse-csi-static-another
        persistentVolumeClaim:
          claimName: "${PERSISTENT_VOLUME_CLAIM_ANOTHER}"
          readOnly: $READONLY
EOF
}

### ENTRYPOINT
echo "------"
echo "${NODE_LOCATIONS}"
#describe_project
#change_default_zone
#echo "------"
#set_quota_project
#gcloud auth application-default login
#echo "------"
#set_projectid
###
create_bucket
create_cluster
echo "------"
get_container_credentials
echo "------"
create_namespace
echo "------"
create_persistent_volume
create_persistent_volume_another
echo "------"
create_persistent_volume_claim
create_persistent_volume_claim_another
echo "------"
create_kubernetes_service_account
create_kubernetes_service_account_another
echo "------"
create_iam_service_account
create_iam_service_account_another
echo "------"
add_a_role_storage_admin
add_a_role_storage_admin_another
echo "------"
add_a_role_logging_logwriter
add_a_role_logging_logwriter_another
echo "------"
add_a_role_monitoring_metricwriter
add_a_role_monitoring_metricwriter_another
echo "------"
add_iam_policy_binding_between_two_service_accounts
add_iam_policy_binding_between_two_service_accounts_another
echo "------"
add_annotation
add_annotation_another
echo "------"
create_deployment_in_original_namespace
create_deployment_in_another_namespace

## Hint
# Please check executing this command that you can write from both namespaces.
#kubectl -it exec <pod> -n <namespace> -c nginx -- /bin/bash
#kubectl -it exec <pod> -n <namespace_another> -c nginx -- /bin/bash
#gsutil ls gs://<buchet>
## You can test creating not deployment but just pod like this also.
#echo "------"
#create_test_pod
#create_pod
#echo "------"
#check_fuse
##delete_pod "${POD_NAME}" "${NAMESPACE}"
###
# delete the pod
