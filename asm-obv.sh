PROJECT_ID=qwiklabs-gcp-03-b6402dee1b7c
mkdir -p secure-gke && cd secure-gke && export WORKDIR=$(pwd)

gcloud config set project ${PROJECT_ID}

cat <<EOF > ${WORKDIR}/vars.sh
export WORKDIR=${WORKDIR}
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export GCLOUD_USER=$(gcloud info --format='value(config.account)')
export WORKLOAD_POOL=$(gcloud info --format='value(config.project)').svc.id.goog
export MESH_ID="proj-$(gcloud projects describe `gcloud info --format='value(config.project)'` --format='value(projectNumber)')"
export CLUSTER_1=gke-west2-a
export CLUSTER_1_ZONE=us-west2-a
export CLUSTER_2=gke-central1-a
export CLUSTER_2_ZONE=us-central1-a
export ASM_CHANNEL=regular
export ASM_LABEL=asm-managed
export KUBECONFIG=${WORKDIR}/asm-kubeconfig
export GSA_READER=asm-reader-sa
EOF

source ${WORKDIR}/vars.sh

gcloud services enable \
--project=${PROJECT_ID} \
anthos.googleapis.com \
container.googleapis.com \
compute.googleapis.com \
monitoring.googleapis.com \
logging.googleapis.com \
cloudtrace.googleapis.com \
meshca.googleapis.com \
meshtelemetry.googleapis.com \
meshconfig.googleapis.com \
iamcredentials.googleapis.com \
gkeconnect.googleapis.com \
gkehub.googleapis.com \
multiclusteringress.googleapis.com \
multiclusterservicediscovery.googleapis.com \
stackdriver.googleapis.com \
sourcerepo.googleapis.com \
cloudresourcemanager.googleapis.com

git clone https://gitlab.com/demos777/secure-gke-asm-acm.git ${WORKDIR}/secure-gke-asm-acm
cd ${WORKDIR}/secure-gke-asm-acm


gcloud container clusters create ${CLUSTER_1} \
  --project ${PROJECT_ID} \
  --zone=${CLUSTER_1_ZONE} \
  --machine-type "e2-standard-4" \
  --num-nodes "4" --min-nodes "4" --max-nodes "6" \
  --monitoring=SYSTEM \
  --logging=SYSTEM,WORKLOAD \
  --enable-ip-alias \
  --enable-autoscaling \
  --workload-pool=${WORKLOAD_POOL} \
  --verbosity=none \
  --labels=mesh_id=${MESH_ID} --async

  gcloud container clusters create ${CLUSTER_2} \
  --project ${PROJECT_ID} \
  --zone=${CLUSTER_2_ZONE} \
  --machine-type "e2-standard-4" \
  --num-nodes "4" --min-nodes "4" --max-nodes "6" \
  --monitoring=SYSTEM \
  --logging=SYSTEM,WORKLOAD \
  --enable-ip-alias \
  --enable-autoscaling \
  --workload-pool=${WORKLOAD_POOL} \
  --verbosity=none \
  --labels=mesh_id=${MESH_ID}

touch ${WORKDIR}/asm-kubeconfig && export KUBECONFIG=${WORKDIR}/asm-kubeconfig
gcloud container clusters get-credentials ${CLUSTER_1} --zone ${CLUSTER_1_ZONE}
gcloud container clusters get-credentials ${CLUSTER_2} --zone ${CLUSTER_2_ZONE}

kubectl config rename-context gke_${PROJECT_ID}_${CLUSTER_1_ZONE}_${CLUSTER_1} ${CLUSTER_1}
kubectl config rename-context gke_${PROJECT_ID}_${CLUSTER_2_ZONE}_${CLUSTER_2} ${CLUSTER_2}

kubectl config get-contexts

# Cluster_1
gcloud container hub memberships register ${CLUSTER_1} \
--project=${PROJECT_ID} \
--gke-cluster=${CLUSTER_1_ZONE}/${CLUSTER_1} \
--enable-workload-identity

# Cluster_2
gcloud container hub memberships register ${CLUSTER_2} \
--project=${PROJECT_ID} \
--gke-cluster=${CLUSTER_2_ZONE}/${CLUSTER_2} \
--enable-workload-identity

gcloud beta container hub mesh enable --project=${PROJECT_ID}
gcloud beta container hub mesh describe


kubectl --context=${CLUSTER_1} wait --for=condition=established crd controlplanerevisions.mesh.cloud.google.com --timeout=5m
kubectl --context=${CLUSTER_2} wait --for=condition=established crd controlplanerevisions.mesh.cloud.google.com --timeout=5m


# Cluster_1
kubectl --context=${CLUSTER_1} apply -f ${WORKDIR}/secure-gke-asm-acm/asm/namespace-istio-system.yaml
sed -e "s/ASM_CHANNEL/${ASM_CHANNEL}/" ${WORKDIR}/secure-gke-asm-acm/asm/controlplanerevision-asm-managed.yaml | kubectl --context=${CLUSTER_1} apply -f -

# Cluster_2
kubectl --context=${CLUSTER_2} apply -f ${WORKDIR}/secure-gke-asm-acm/asm/namespace-istio-system.yaml
sed -e "s/ASM_CHANNEL/${ASM_CHANNEL}/" ${WORKDIR}/secure-gke-asm-acm/asm/controlplanerevision-asm-managed.yaml | kubectl --context=${CLUSTER_2} apply -f -


kubectl --context=${CLUSTER_1} wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s
kubectl --context=${CLUSTER_2} wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s


# Cluster_1
sed -e "s/ASM_LABEL/${ASM_LABEL}/" ${WORKDIR}/secure-gke-asm-acm/asm/namespace-asm-gateways.yaml | kubectl --context=${CLUSTER_1} apply -f -
kubectl --context=${CLUSTER_1} apply -f ${WORKDIR}/secure-gke-asm-acm/asm/asm-ingressgateway.yaml

# Cluster_2
sed -e "s/ASM_LABEL/${ASM_LABEL}/" ${WORKDIR}/secure-gke-asm-acm/asm/namespace-asm-gateways.yaml | kubectl --context=${CLUSTER_2} apply -f -
kubectl --context=${CLUSTER_2} apply -f ${WORKDIR}/secure-gke-asm-acm/asm/asm-ingressgateway.yaml

curl https://storage.googleapis.com/csm-artifacts/asm/asmcli > asmcli
chmod +x asmcli
./asmcli create-mesh \
    ${PROJECT_ID} \
    ${PROJECT_ID}/${CLUSTER_1_ZONE}/${CLUSTER_1} \
    ${PROJECT_ID}/${CLUSTER_2_ZONE}/${CLUSTER_2}

gcloud compute firewall-rules create --network default --allow tcp --direction ingress --source-ranges 10.0.0.0/8 all

git clone https://gitlab.com/anthos-multicloud/anthos-multicloud-workshop ${WORKDIR}/multicloud-workshop
cd ${WORKDIR}/multicloud-workshop


#!/usr/bin/env bash
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Export a SCRIPT_DIR var and make all links relative to SCRIPT_DIR
export SCRIPT_DIR=$(dirname $(readlink -f $0 2>/dev/null) 2>/dev/null || echo "${PWD}/$(dirname $0)")

# Source required include files
source ${SCRIPT_DIR}/include/display.sh
source ${SCRIPT_DIR}/include/kubernetes.sh

# Define vars
export GKE1=${CLUSTER_1}
export GKE2=${CLUSTER_2}
export DEV_NS=ob-dev

## Stage 1: Preparation
ASM_REV_LABEL=asm-managed

sed -e "s/ASM_REV_LABEL/${ASM_REV_LABEL}/" ${SCRIPT_DIR}/ob/dev/gke1/ob-namespace-patch.yaml_tmpl > ${SCRIPT_DIR}/ob/dev/gke1/ob-namespace-patch.yaml
sed -e "s/ASM_REV_LABEL/${ASM_REV_LABEL}/" ${SCRIPT_DIR}/ob/dev/gke2/ob-namespace-patch.yaml_tmpl > ${SCRIPT_DIR}/ob/dev/gke2/ob-namespace-patch.yaml

## Stage 2: Deploy
echo -e "\n"
echo_cyan "*** Deploying Online Boutique app to ${GKE1} cluster... ***\n"
kubectl --context=${GKE1} apply -k ${SCRIPT_DIR}/ob/dev/gke1
echo -e "\n"
echo_cyan "*** Deploying Online Boutique app to ${GKE2} cluster... ***\n"
kubectl --context=${GKE2} apply -k ${SCRIPT_DIR}/ob/dev/gke2

## Stage 3: Validation
echo -e "\n"
echo_cyan "*** Verifying all Deployments are Ready in all clusters... ***\n"
is_deployment_ready ${GKE1} ${DEV_NS} emailservice
is_deployment_ready ${GKE1} ${DEV_NS} checkoutservice
is_deployment_ready ${GKE1} ${DEV_NS} frontend

is_deployment_ready ${GKE1} ${DEV_NS} paymentservice
is_deployment_ready ${GKE1} ${DEV_NS} productcatalogservice
is_deployment_ready ${GKE1} ${DEV_NS} currencyservice

is_deployment_ready ${GKE2} ${DEV_NS} shippingservice
is_deployment_ready ${GKE2} ${DEV_NS} adservice
is_deployment_ready ${GKE2} ${DEV_NS} loadgenerator

is_deployment_ready ${GKE2} ${DEV_NS} cartservice
is_deployment_ready ${GKE2} ${DEV_NS} recommendationservice

echo -e "\n"
echo_cyan "*** Access Online Boutique app in namespace ${DEV_NS} by navigating to the following address: ***\n"
echo -n "http://"
kubectl --context=${GKE1} -n asm-gateways get svc asm-ingressgateway -o jsonpath={.status.loadBalancer.ingress[].ip}
echo -e "\n"

# change ob
# pwd/home/student_00_1fffbe42bb7f/secure-gke/multicloud-workshop/platform_admins/tests/ob/dev/gke1/istio-control.yaml - istio: ingressgateway -> asm: ingressgateway

${WORKDIR}/multicloud-workshop/platform_admins/tests/ops/asm-slo.sh \
  ${PROJECT_ID} ob-dev

kubectl --context ${CLUSTER_1} \
  -n ob-dev \
  apply -f ${WORKDIR}/multicloud-workshop/platform_admins/tests/ops/virtualservice-cartservice-50fault.yaml

# reload page
21:03:50 21:07:00
#out of budget

21:08:15 - alert