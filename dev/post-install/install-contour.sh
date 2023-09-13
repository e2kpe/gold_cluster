#!/bin/bash

tanzu package install cert-manager  --package-name cert-manager.tanzu.vmware.com --version 1.7.2+vmware.1-tkg.1 -n cert-manager --create-namespace

tanzu package install contour  --package-name contour.tanzu.vmware.com --version 1.20.2+vmware.1-tkg.1 -n contour --create-namespace --values-file contour-default-values.yaml

kubectl get pods -n tanzu-system-ingress 
