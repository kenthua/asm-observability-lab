# Verify imported varables
echo -e "PROJECT_ID is ${PROJECT_ID}"

function join_by { local IFS="$1"; shift; echo "$*"; }
ALL_CLUSTER_CIDRS=$(gcloud container clusters list --project ${PROJECT_ID} --format='value(clusterIpv4Cidr)' | sort | uniq)
ALL_CLUSTER_CIDRS=$(join_by , $(echo "${ALL_CLUSTER_CIDRS}"))
ALL_CLUSTER_NETTAGS=$(gcloud compute instances list --project ${PROJECT_ID} --format='value(tags.items.[0])' | sort | uniq)
ALL_CLUSTER_NETTAGS=$(join_by , $(echo "${ALL_CLUSTER_NETTAGS}"))

echo -e "ALL_CLUSTER_CIDRS: ${ALL_CLUSTER_CIDRS}"
echo -e "ALL_CLUSTER_NETTAGS: ${ALL_CLUSTER_NETTAGS}"

# autopilot doesn't have nettags

# gcloud compute firewall-rules  list | grep istio-multicluster-pods | wc -l
if [ ! $(gcloud compute firewall-rules  list | grep istio-multicluster-pods | wc -l) = "1" ]; then
    gcloud compute firewall-rules create istio-multicluster-pods \
        --allow=tcp,udp,icmp,esp,ah,sctp \
        --direction=INGRESS \
        --priority=900 \
        --source-ranges="${ALL_CLUSTER_CIDRS}" \
        --quiet \
        --project ${PROJECT_ID}
    else
        echo "Firewall rule exists"
fi