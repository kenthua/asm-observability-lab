PROJECT_ID=${1:-${GOOGLE_CLOUD_PROJECT}}

gcloud config set project ${PROJECT_ID}

cat <<EOF > ${WORKDIR}/vars.sh
export WORKDIR=${WORKDIR}
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export GCLOUD_USER=$(gcloud info --format='value(config.account)')
export CLUSTER_1=gke-prod-1
export CLUSTER_1_LOCATION=us-west2
export CLUSTER_2=gke-prod-2
export CLUSTER_2_LOCATION=us-central1
export ASM_CHANNEL=regular
export ASM_LABEL=asm-managed
export KUBECONFIG=${WORKDIR}/asm-kubeconfig
alias k=kubectl
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
multiclustermetering.googleapis.com \
stackdriver.googleapis.com \
sourcerepo.googleapis.com \
cloudresourcemanager.googleapis.com

gcloud container clusters create-auto ${CLUSTER_1} \
  --project ${PROJECT_ID} \
  --region=${CLUSTER_1_LOCATION} \
  --verbosity=none \
  --async

  gcloud container clusters create-auto ${CLUSTER_2} \
  --project ${PROJECT_ID} \
  --region=${CLUSTER_2_LOCATION}

touch ${WORKDIR}/asm-kubeconfig && export KUBECONFIG=${WORKDIR}/asm-kubeconfig
gcloud container clusters get-credentials ${CLUSTER_1} --zone ${CLUSTER_1_LOCATION}
gcloud container clusters get-credentials ${CLUSTER_2} --zone ${CLUSTER_2_LOCATION}

kubectl config rename-context gke_${PROJECT_ID}_${CLUSTER_1_LOCATION}_${CLUSTER_1} ${CLUSTER_1}
kubectl config rename-context gke_${PROJECT_ID}_${CLUSTER_2_LOCATION}_${CLUSTER_2} ${CLUSTER_2}

kubectl config get-contexts

# Cluster_1
gcloud container hub memberships register ${CLUSTER_1} \
--project=${PROJECT_ID} \
--gke-cluster=${CLUSTER_1_LOCATION}/${CLUSTER_1} \
--enable-workload-identity

# Cluster_2
gcloud container hub memberships register ${CLUSTER_2} \
--project=${PROJECT_ID} \
--gke-cluster=${CLUSTER_2_LOCATION}/${CLUSTER_2} \
--enable-workload-identity

gcloud beta container hub mesh enable --project=${PROJECT_ID}
gcloud beta container hub mesh describe

# wait for reg
while true 
do
    if [ $(gcloud beta container hub mesh describe --format=json | grep OK | wc -l) == "2" ]; then
        break;
    fi
    sleep 5;
    echo "Registration -- Sleep and then check..."
done

## manual control plane

# kubectl --context=${CLUSTER_1} wait --for=condition=established crd controlplanerevisions.mesh.cloud.google.com --timeout=5m
# kubectl --context=${CLUSTER_2} wait --for=condition=established crd controlplanerevisions.mesh.cloud.google.com --timeout=5m

## Cluster_1
# kubectl --context=${CLUSTER_1} apply -f ${WORKDIR}/lab/bootstrap/k8s/namespace-istio-system.yaml
# sed -e "s/ASM_CHANNEL/${ASM_CHANNEL}/" ${WORKDIR}/lab/bootstrap/k8s/controlplanerevision-asm-managed.yaml | kubectl --context=${CLUSTER_1} apply -f -

## Cluster_2
# kubectl --context=${CLUSTER_2} apply -f ${WORKDIR}/lab/bootstrap/k8s/namespace-istio-system.yaml
# sed -e "s/ASM_CHANNEL/${ASM_CHANNEL}/" ${WORKDIR}/lab/bootstrap/k8s/controlplanerevision-asm-managed.yaml | kubectl --context=${CLUSTER_2} apply -f -

# kubectl --context=${CLUSTER_1} wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s
# kubectl --context=${CLUSTER_2} wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s

## auto control plane
## https://cloud.google.com/service-mesh/docs/managed/auto-control-plane-with-fleet#enable
gcloud alpha container hub mesh update \
    --control-plane automatic \
    --membership ${CLUSTER_1} \
    --project ${PROJECT_ID}
gcloud alpha container hub mesh update \
    --control-plane automatic \
    --membership ${CLUSTER_2} \
    --project ${PROJECT_ID}

# wait for crd provisioning
while true 
do
    if [ $(kubectl get controlplanerevision asm-managed -n istio-system --no-headers | grep asm-managed | wc -l) == "1" ]; then
        break;
    fi
    sleep 5;
    echo "Mesh CRD - Sleep and then check..."
done

kubectl --context=${CLUSTER_1} wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s
kubectl --context=${CLUSTER_2} wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s

# Cluster_1
sed -e "s/ASM_LABEL/${ASM_LABEL}/" ${WORKDIR}/lab/bootstrap/k8s/namespace-asm-gateways.yaml | kubectl --context=${CLUSTER_1} apply -f -
kubectl --context=${CLUSTER_1} apply -f ${WORKDIR}/lab/bootstrap/k8s/asm-ingressgateway.yaml

# Cluster_2
sed -e "s/ASM_LABEL/${ASM_LABEL}/" ${WORKDIR}/lab/bootstrap/k8s/namespace-asm-gateways.yaml | kubectl --context=${CLUSTER_2} apply -f -
kubectl --context=${CLUSTER_2} apply -f ${WORKDIR}/lab/bootstrap/k8s/asm-ingressgateway.yaml

curl https://storage.googleapis.com/csm-artifacts/asm/asmcli > asmcli
chmod +x asmcli
./asmcli create-mesh \
    ${PROJECT_ID} \
    ${PROJECT_ID}/${CLUSTER_1_LOCATION}/${CLUSTER_1} \
    ${PROJECT_ID}/${CLUSTER_2_LOCATION}/${CLUSTER_2}

# firewall rule for multi-subnet clusters
function join_by { local IFS="$1"; shift; echo "$*"; }
ALL_CLUSTER_CIDRS=$(gcloud container clusters list --project ${PROJECT_ID} --format='value(clusterIpv4Cidr)' | sort | uniq)
ALL_CLUSTER_CIDRS=$(join_by , $(echo "${ALL_CLUSTER_CIDRS}"))
ALL_CLUSTER_NETTAGS=$(gcloud compute instances list --project ${PROJECT_ID} --format='value(tags.items.[0])' | sort | uniq)
ALL_CLUSTER_NETTAGS=$(join_by , $(echo "${ALL_CLUSTER_NETTAGS}"))

gcloud compute firewall-rules create istio-multicluster-pods \
    --quiet \
    --allow=tcp,udp,icmp,esp,ah,sctp \
    --direction=INGRESS \
    --priority=900 \
    --source-ranges="${ALL_CLUSTER_CIDRS}"
#    --target-tags="${ALL_CLUSTER_NETTAGS}"

${WORKDIR}/lab/workload/ob.sh

${WORKDIR}/lab/workload/ops/services-dashboard.sh \
  ${WORKDIR}/lab/workload/ops/services-dashboard-prod.json_tmpl