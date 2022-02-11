#!/bin/bash

# Check var PROJECT_ID is set
[[ ! "${PROJECT_ID}" ]] && echo -e "PROJECT_ID variable is not set. Please set the PROJECT_ID variables and retry." && exit 1
[[ "${PROJECT_ID}" ]] && echo -e "Your project ID is set to ${PROJECT_ID}."

# sets the current project for gcloud
gcloud config set project $PROJECT_ID

# Enables various APIs you'll need
gcloud services enable \
    container.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    clouddeploy.googleapis.com \
    cloudresourcemanager.googleapis.com \
    sourcerepo.googleapis.com

# creates a CSR repo for the app
export CSR_REPO=$(gcloud --project=${PROJECT_ID} source repos list --format='value(name)')
[[ "${CSR_REPO}" -eq "app-repo" ]] && echo -e "Cloud Source repo ${CSR_REPO} already exists."
[[ ! "${CSR_REPO}" -eq "app-repo" ]] && gcloud --project=${PROJECT_ID} source repos create app-repo

# creates the Artifact Registry repo
export ARTIFACT_REPO=$(gcloud --project=${PROJECT_ID} artifacts repositories list --format='value(name)')
[[ "${ARTIFACT_REPO}" -eq "pop-stats" ]] && echo -e "Artifact repo ${ARTIFACT_REPO} already exists."
[[ ! "${ARTIFACT_REPO}" -eq "pop-stats" ]] && gcloud --project=${PROJECT_ID} artifacts repositories create pop-stats --location=us-central1 \
    --repository-format=docker

# creates the Google Cloud Deploy pipeline
export DELIVERY_PIPELINE=$(gcloud --project=$PROJECT_ID deploy delivery-pipelines list --region=us-central1 --format='value(name)')
export EXPECTED_DELIVERY_PIPELINE=projects/${PROJECT_ID}/locations/us-central1/deliveryPipelines/pop-stats-pipeline
[[ "${DELIVERY_PIPELINE}" == "${EXPECTED_DELIVERY_PIPELINE}" ]] && echo -e "Delivery pipeline $DELIVERY_PIPELINE already exists."
[[ ! "${DELIVERY_PIPELINE}" == "${EXPECTED_DELIVERY_PIPELINE}" ]] && gcloud --project=$PROJECT_ID deploy apply --file clouddeploy.yaml \
    --region=us-central1

echo "init done. To create clusters, run: ./gke-cluster-init.sh"
