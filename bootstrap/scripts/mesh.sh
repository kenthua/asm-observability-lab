#!/usr/bin/env bash

# Verify imported varables
echo -e "KUBECONFIG is ${KUBECONFIG}"
echo -e "CLUSTER is ${CLUSTER}"
echo -e "LOCATION is ${LOCATION}"

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