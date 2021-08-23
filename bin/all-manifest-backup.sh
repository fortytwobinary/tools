#!/bin/bash

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
echo $TIMESTAMP

kubectl get all --all-namespaces -o yaml > /backups/$TIMESTAMP-all-manifests.yml


