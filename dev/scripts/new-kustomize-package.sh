#to add a new post-install


packagename=<put package name here>
packagenamespace=$packagename


mkdir ./dev/post-install/$packagename
#copy required install files in to ./dev/post-install/$packagename
cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ${packagename}.yaml
EOF > ./dev/post-install/${packagename}/kustomization.yaml

### this is your package install
touch ./dev/post-install/${packagename}/${packagename}.yaml

### set up kustomize for the package
sed -i "/resources:/a -\ ${packagename}.yaml" ./dev/kustomize/kustomization.yaml

cat <<EOF
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: ${packagename}
  namespace: tanzu-continuousdelivery-resources
spec:
  dependsOn:
    - name: tanzu-packages-namespaces
    - name: tanzu-packages-serviceaccounts
  interval: 1m0s
  path: ./dev/post-install/$packagename
  prune: true
  sourceRef:
    kind: GitRepository
    name: base-packages
    namespace: tanzu-continuousdelivery-resources
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: $packagename
      namespace: $packagenamespace
EOF > ./dev/kustomize/${packagename}.yaml

### set up prereqs for namespace and service account
mkdir -p ./dev/prereqs/namespaces/${packagenamespace}
cat <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${packagenamespace}
EOF > ./dev/prereqs/namespaces/${packagenamespace}.yaml

mkdir -p ./dev/prereqs/servicesaccount/${packagename}-sa
cat <<EOF
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: ${packagename}-sa
  namespace: tanzu-continuousdelivery-resources
spec:
  dependsOn:
    - name: tanzu-packages-namespaces
  interval: 1m0s
  path: ./dev/post-install/serviceaccount/${packagename}-sa/
  prune: true
  sourceRef:
    kind: GitRepository
    name: base-packages
    namespace: tanzu-continuousdelivery-resources
EOF > ./dev/prereqs/serviceaccount/${packagename}-sa.yaml

###########
##
##  If a package requires $cluster_name
##  then add it to ./dev/prereqs/cluster-name-secrets.yaml as a new import
##
