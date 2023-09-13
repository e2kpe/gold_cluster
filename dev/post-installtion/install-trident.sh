#!/bin/bash
kubectl create ns trident
kubectl create -f imagepull-secret.yaml -n trident


./trident-installer/tridentctl install -n trident --use-custom-yaml

./trident-installer/tridentctl create  backend -n trident -f backend.json

kubectl apply -f storage-class.yaml

