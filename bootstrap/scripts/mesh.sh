#!/usr/bin/env bash

# Verify imported varables
echo -e "KUBECONFIG is ${KUBECONFIG}"
echo -e "CLUSTER is ${CLUSTER}"
echo -e "LOCATION is ${LOCATION}"
echo -e "ASM CHANNEL is ${ASM_CHANNEL}"
echo -e "ASM LABEL is ${ASM_LABEL}"

# Idempotent command to enable mesh
gcloud beta container hub mesh enable --project=${PROJECT}

# Get cluster creds
gcloud container clusters get-credentials ${CLUSTER} --zone ${LOCATION} --project ${PROJECT}

# Wait for 10 mins to ensure controlplanerevision CRD is present in the cluster
for NUM in {1..60} ; do
  kubectl get crd | grep controlplanerevisions.mesh.cloud.google.com && break
  sleep 10
done

# Verify CRD is established in the cluster
kubectl wait --for=condition=established crd controlplanerevisions.mesh.cloud.google.com --timeout=10m

# Create istio ns
kubectl apply -f ../k8s/namespace-istio-system.yaml

# Apply Control Plane CR
sed -e "s/ASM_CHANNEL/${ASM_CHANNEL}/" ../k8s/controlplanerevision-asm-managed.yaml | kubectl apply -f -

# Verify control plane is provisioned
kubectl wait --for=condition=ProvisioningFinished controlplanerevision asm-managed -n istio-system --timeout 600s

# Create ASM gateway ns
sed -e "s/ASM_LABEL/${ASM_LABEL}/" ../k8s/namespace-asm-gateways.yaml | kubectl apply -f -

# Apply ASM Gateway
kubectl apply -f ../k8s/asm-ingressgateway.yaml
