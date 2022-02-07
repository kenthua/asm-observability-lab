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

```
# lab
${WORKDIR}/lab/workload/ops/asm-slo.sh \
  ${GOOGLE_CLOUD_PROJECT} ob

kubectl --context ${CLUSTER_1} \
  -n ob \
  apply -f ${WORKDIR}/lab/workload/ops/virtualservice-cartservice-50fault.yaml
```

```
kubectl --context ${CLUSTER_1} \
  -n ob \
  delete -f ${WORKDIR}/lab/workload/ops/virtualservice-cartservice-50fault.yaml
```