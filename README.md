Run this in cloud shell
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