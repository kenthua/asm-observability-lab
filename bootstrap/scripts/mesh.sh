#!/usr/bin/env bash

# Verify imported varables
echo -e "PROJECT_ID is ${PROJECT_ID}"
echo -e "PROJECT_NUMBER is ${PROJECT_NUMBER}"
echo -e "KUBECONFIG is ${KUBECONFIG}"
echo -e "CLUSTER is ${CLUSTER}"
echo -e "LOCATION is ${LOCATION}"
echo -e "ASM CHANNEL is ${ASM_CHANNEL}"
echo -e "ASM LABEL is ${ASM_LABEL}"
echo -e "MODULE PATH is ${MODULE_PATH}"

# Idempotent command to enable mesh
gcloud beta container hub mesh enable --project=${PROJECT_ID}

# Get cluster creds
gcloud container clusters get-credentials ${CLUSTER} --zone ${LOCATION} --project ${PROJECT_ID}

# Wait for 10 mins to ensure controlplanerevision CRD is present in the cluster
for NUM in {1..60} ; do
  kubectl get crd | grep controlplanerevisions.mesh.cloud.google.com && break
  sleep 10
done

# Verify CRD is established in the cluster
kubectl wait --for=condition=established crd controlplanerevisions.mesh.cloud.google.com --timeout=10m

# apply mesh_id label
gcloud container clusters update ${CLUSTER} \
    --project ${PROJECT_ID} \
    --region ${LOCATION} \
    --update-labels=mesh_id=proj-${PROJECT_NUMBER}

# Create istio ns
kubectl apply -f ${MODULE_PATH}/k8s/namespace-istio-system.yaml

# Apply Control Plane CR
sed -e "s/ASM_CHANNEL/${ASM_CHANNEL}/" ${MODULE_PATH}/k8s/controlplanerevision-asm-managed.yaml | kubectl apply -f -

# Verify control plane is provisioned
kubectl wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s

# Create ASM gateway ns
sed -e "s/ASM_LABEL/${ASM_LABEL}/" ${MODULE_PATH}/k8s/namespace-asm-gateways.yaml | kubectl apply -f -

# Apply ASM Gateway
kubectl apply -f ${MODULE_PATH}/k8s/asm-ingressgateway.yaml