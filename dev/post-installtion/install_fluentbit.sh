#!/bin/bash
printf  " Cluster name in fluentbit.yaml \n"
grep "cluster=" fluentbit.yaml

read -p "is above cluster name is correct ? press y to continue:"  ans

if [ $ans == "y" ]
then

tanzu package install fluent-bit --package-name fluent-bit.tanzu.vmware.com --version 1.8.15+vmware.1-tkg.1 --values-file fluentbit.yaml --namespace  e2open-tanzu-packages

else
printf "update the clustername in fluentbit.yaml"
exit
