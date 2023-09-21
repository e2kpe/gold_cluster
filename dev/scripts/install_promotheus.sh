#!/bin/bash
printf  " Cluster name in dev-prometheus-default-values.yaml \n"

grep -w "cluster:" dev-prometheus-default-values.yaml
echo -n 
read -p "is above cluster name is correct ? press y to continue:"  ans

if [ $ans == "y" ]
then
tanzu package install prometheus --package-name prometheus.tanzu.vmware.com --version 2.36.2+vmware.1-tkg.1 --values-file dev-prometheus-default-values.yaml --namespace e2open-tanzu-packages 
else 
printf "update the clustername in dev-prometheus-default-values.yaml" 
exit

fi

