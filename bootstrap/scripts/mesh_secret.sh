# Verify imported varables
echo -e "PROJECT_ID is ${PROJECT_ID}"
echo -e "CLUSTER_1 is ${CLUSTER_1}"
echo -e "LOCATION_1 is ${LOCATION_1}"
echo -e "CLUSTER_2 is ${CLUSTER_2}"
echo -e "LOCATION_2 is ${LOCATION_2}"

curl https://storage.googleapis.com/csm-artifacts/asm/asmcli > asmcli
chmod +x asmcli
./asmcli create-mesh \
    ${PROJECT_ID} \
    ${PROJECT_ID}/${LOCATION_1}/${CLUSTER_1} \
    ${PROJECT_ID}/${LOCATION_2}/${CLUSTER_2}