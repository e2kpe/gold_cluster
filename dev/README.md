#to add a new post-install that uses kustomize

#mkdir ./dev/post-install/$packagename
#copy required install files in to ./dev/post-install/$packagename
add packagename.yaml to resources: in  ./dev/post-install/$packagename/kustomization.yaml

### this is your package install
touch ./dev/post-install/${packagename}/${packagename}.yaml

### set up base kustomize for the package
sed -i "/resources:/a -\ ${packagename}.yaml" ./dev/kustomize/kustomization.yaml

create ./dev/kustomize/${packagename}.yaml with metadata.name: dependencies and deployment healthcheck

### set up prereqs for namespace and service account
mkdir -p ./dev/prereqs/namespaces/${packagenamespace}
set metadata.name in ./dev/prereqs/namespaces/${packagenamespace}.yaml

mkdir -p ./dev/prereqs/servicesaccount/${packagename}-sa
set metadata.name and path in ./dev/prereqs/serviceaccount/${packagename}-sa.yaml

###########
##
##  If a package requires $cluster_name
##  then add it to ./dev/prereqs/cluster-name-secrets.yaml as a new import
##
