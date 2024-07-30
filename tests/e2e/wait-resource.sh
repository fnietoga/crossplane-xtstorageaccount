#!/bin/bash

EXPECTED_ARGS=6
if [[ $# -ne $EXPECTED_ARGS ]]; then
    printf "Usage:\n"
    printf " $(basename $0) -g <composition_group> -t <composition_type> -n <composition_name>\n"
    exit 1
fi

while getopts "g:t:n:" flag
do
    case "${flag}" in
        g) COMPOSITION_GROUP=${OPTARG};;
        t) COMPOSITION_TYPE=${OPTARG};;
        n) COMPOSITION_NAME=${OPTARG};;
        *) printf "ERROR: ${OPTARG} is a invalid parameter\n";;
    esac
done
RESOURCE_TO_WAIT="${COMPOSITION_TYPE,,}.${COMPOSITION_GROUP}/${COMPOSITION_NAME}"
echo "Wait for composite resources with params:"
echo "  COMPOSITION_GROUP: $COMPOSITION_GROUP";
echo "  COMPOSITION_TYPE: $COMPOSITION_TYPE";
echo "  COMPOSITION_NAME: $COMPOSITION_NAME";
echo "  RESOURCE_TO_WAIT: $RESOURCE_TO_WAIT";

# Wait for Resource to become fully available before proceeding
echo "Waiting for resource $RESOURCE_TO_WAIT to be Ready..."
kubectl wait --for condition=Ready --timeout=180s $RESOURCE_TO_WAIT
# if error or timeout occurs
if [ $? -gt 0 ]; then
    ##Get events for composition resource
    echo "-> Describing events for composition: $COMPOSITION_TYPE/$COMPOSITION_NAME..."
    kubectl describe $COMPOSITION_TYPE $COMPOSITION_NAME | grep -A20 Events

    ##Get events for claim resource
    if kubectl describe $COMPOSITION_TYPE $COMPOSITION_NAME | grep -q "Resource Ref"; then 
        CLAIM_NAME=$(kubectl describe $COMPOSITION_TYPE $COMPOSITION_NAME | yq -p yaml -r '.Spec.["Resource Ref"].Name')
        CLAIM_TYPE=$(kubectl describe $COMPOSITION_TYPE $COMPOSITION_NAME | yq -p yaml -r '.Spec.["Resource Ref"].Kind')
        if [ ! -z "$CLAIM_NAME" ] && [ ! -z "$CLAIM_TYPE" ]; then
            echo "-> Describing events for claim: $CLAIM_TYPE/$CLAIM_NAME..."
            kubectl describe $CLAIM_TYPE $CLAIM_NAME | grep -A20 Events
        fi
    fi

    ##Get events for Azure resources
    if kubectl describe $CLAIM_TYPE $CLAIM_NAME | grep -q "Resource Refs"; then 
        RESOURCE_NAME=$(kubectl describe $CLAIM_TYPE $CLAIM_NAME | yq -p yaml -r '.Spec.["Resource Refs"].Name')
        RESOURCE_TYPE=$(kubectl describe $CLAIM_TYPE $CLAIM_NAME | yq -p yaml -r '.Spec.["Resource Refs"].Kind')
        if [ ! -z "$RESOURCE_NAME" ] && [ ! -z "$RESOURCE_TYPE" ]; then
            echo "-> Describing events for resource: $RESOURCE_TYPE/$RESOURCE_NAME..."
            kubectl describe $RESOURCE_TYPE $RESOURCE_NAME | grep -A20 Events
        fi
    fi
    echo "exit with errorLevel 1"
    exit 1
fi