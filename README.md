# Install
## Scripted
```
gcloud config set project ${GOOGLE_CLOUD_PROJECT}

mkdir -p asm-observability && cd asm-observability && export WORKDIR=$(pwd)

git clone https://github.com/kenthua/asm-observability-lab ${WORKDIR}/lab
cd ${WORKDIR}/lab

${WORKDIR}/lab/setup.sh ${GOOGLE_CLOUD_PROJECT}

# Need to let the app settle itself before we try to measure, otherwise availability is impacted if SLOs are configured right after app deployment
sleep 300
uptime
echo "Wait Done"
```

## Terraform
```
gcloud config set project ${GOOGLE_CLOUD_PROJECT}

mkdir -p asm-observability && cd asm-observability && export WORKDIR=$(pwd)

cat <<EOF > ${WORKDIR}/vars.sh
export PROJECT_ID=${GOOGLE_CLOUD_PROJECT}
export CLUSTER_1=gke-prod-1
export CLUSTER_2=gke-prod-2
export CLUSTER_1_LOCATION=us-west2
export CLUSTER_2_LOCATION=us-central1
export ASM_CHANNEL=regular
export ASM_LABEL=asm-managed
alias k=kubectl
EOF

source ${WORKDIR}/vars.sh

git clone https://github.com/kenthua/asm-observability-lab ${WORKDIR}/lab
cd ${WORKDIR}/lab

# setup tf state bucket
gcloud config set project ${PROJECT_ID}
gsutil mb -p ${PROJECT_ID} gs://${PROJECT_ID}
gsutil versioning set on gs://${PROJECT_ID}

# set variables
cd ${WORKDIR}/lab/bootstrap
envsubst < backend.tf_tmpl > backend.tf
envsubst < variables.tfvars_tmpl > variables.tfvars

terraform init -var-file=variables.tfvars
terraform plan -var-file=variables.tfvars
terraform apply -auto-approve -var-file=variables.tfvars

# get cluster kubeconfig
touch ${WORKDIR}/asm-kubeconfig && export KUBECONFIG=${WORKDIR}/asm-kubeconfig
gcloud container clusters get-credentials ${CLUSTER_1} --zone ${CLUSTER_1_LOCATION}
gcloud container clusters get-credentials ${CLUSTER_2} --zone ${CLUSTER_2_LOCATION}

kubectl config rename-context gke_${PROJECT_ID}_${CLUSTER_1_LOCATION}_${CLUSTER_1} ${CLUSTER_1}
kubectl config rename-context gke_${PROJECT_ID}_${CLUSTER_2_LOCATION}_${CLUSTER_2} ${CLUSTER_2}

kubectl config get-contexts

# setup app
${WORKDIR}/lab/workload/ob.sh

# setup dashboard
${WORKDIR}/lab/workload/ops/services-dashboard.sh \
  ${WORKDIR}/lab/workload/ops/services-dashboard-prod.json_tmpl
```

# Labs
This is where the lab begins scripted or manually [here](./docs/asm-slo.md)
```
# Setup the shell variables
source ~/asm-observability/vars.sh

# Generate the SLOs
${WORKDIR}/lab/workload/ops/asm-slo.sh \
  ${GOOGLE_CLOUD_PROJECT} ob

echo "*** Access Online Boutique app by navigating to the following address: ***\n"
echo "http://$(kubectl --context=${CLUSTER_1} -n asm-gateways get svc asm-ingressgateway -o jsonpath={.status.loadBalancer.ingress[].ip})"

# Create the fault to generate errors
kubectl --context ${CLUSTER_1} \
  -n ob \
  apply -f ${WORKDIR}/lab/workload/ops/virtualservice-cartservice-50fault.yaml
```

Delete the virtual service fault
```
kubectl --context ${CLUSTER_1} \
  -n ob \
  delete -f ${WORKDIR}/lab/workload/ops/virtualservice-cartservice-50fault.yaml
```