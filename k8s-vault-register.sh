#!/bin/bash
#here in this example vault-auth service-account created in external-secrets

source ~/vault-infosec-demo/.vault-login.sh
# createing namespace service account
kubectl get ns external-secrets || kubectl create ns external-secrets
kubectl get sa vault-auth -n external-secrets ||kubectl apply -f - <<EON
apiVersion: v1
kind: ServiceAccount
metadata:
  name: valut-auth
  namespace: external-secrets
secrets:
- name: vault-auth-token
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-auth-token
  namespace: external-secrets
  annotations:
    kubernetes.io/service-account.name: vault-auth
type: kubernetes.io/service-account-token


EON

cat <<EOF |kubectl apply -f  -
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: external-secrets

EOF

kubectl  apply -f ~/src/tanzu-bootstrap/svl-dev/main/imagepull-secret.yaml -n external-secrets
export TKC_NAME=$(kubectl config current-context)

kubectl cluster-info |head -1 |awk '{ print $7}'

read -p "enter the url:" TKC_URL
export TKC_URL

export VAULT_SA_NAME=$(kubectl get sa -n external-secrets vault-auth --output jsonpath="{.secrets[*]['name']}")

export SA_JWT_TOKEN=$(kubectl get secret -n external-secrets $VAULT_SA_NAME --output 'go-template={{ .data.token }}' | base64 --decode)
echo $SA_JWT_TOKEN > ${TKC_NAME}_SA_JWT_TOKEN
kubectl config view --raw --minify --flatten --output='jsonpath={.clusters[].cluster.certificate-authority-data}' | base64 --decode  > ${TKC_NAME}-ca.crt

vault auth enable  -path /${TKC_NAME} kubernetes

vault write auth/${TKC_NAME}/config token_reviewer_jwt=$(cat  ${TKC_NAME}_SA_JWT_TOKEN) kubernetes_host=${TKC_URL} kubernetes_ca_cert=@${TKC_NAME}-ca.crt disable_local_ca_jwt=true

echo " installing external-secrets  "

helm install external-secrets ~/src/tanzu-bootstrap/e2open-helm-charts/external-secrets-0.8.0 -n  external-secrets --wait
kubectl apply -f vault-ca-cm.yaml
### creating KV path for each tkc-cluster
vault secrets enable -version=2 -path=${TKC_NAME}  kv

#for kns in `kubectl get ns -l CI-Environment=DEV|grep -iv NAME|awk '{print $1}'`
for kns in `cat /tmp/list` 
do

kubectl get sa vault-auth -n ${kns} || kubectl create sa vault-auth -n ${kns}
vault kv put ${TKC_NAME}/${kns}/demosecret username="demo1-user" password="mypassword"

cat << EOF > policies/policy-${TKC_NAME}-${kns}.hcl
path "${TKC_NAME}/data/${kns}/*" {
  capabilities = ["list","read"]
}

path "${TKC_NAME}/metadata/${kns}/" {
  capabilities = ["list"]
}

EOF

vault policy write  policy-${TKC_NAME}-${kns} policies/policy-${TKC_NAME}-${kns}.hcl
#vault secrets enable -version=2 -path=common-secrets kv
#vault kv put common-secrets/common-secrets/wildcard-certs cert=@domain.crt key=@cert.key

vault write auth/${TKC_NAME}/role/${kns} \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=${kns} \
        policies=policy-${TKC_NAME}-${kns},default \
        ttl=24h
cat << EOD > secret-stores/${TKC_NAME}-${kns}-ss.yaml
apiVersion: v1
items:
- apiVersion: external-secrets.io/v1beta1
  kind: SecretStore
  metadata:
    name: vault
    namespace: ${kns}
  spec:
    provider:
      vault:
        auth:
          kubernetes:
            mountPath: ${TKC_NAME}
            role: ${kns}
            serviceAccountRef:
              name: vault-auth
        caProvider:
          key: vault-ca.crt
          name: vault-ca
          namespace: kube-public
          type: ConfigMap
        path:  ${TKC_NAME}
        server: https://vault.dev.e2open.com
        version: v2
kind: List
metadata:
  resourceVersion: ""
  selfLink: ""
EOD


kubectl apply -f secret-stores/${TKC_NAME}-${kns}-ss.yaml -n ${kns}


cat << EOM > secret-stores/${TKC_NAME}-${kns}-es.yaml 
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name:  external-secret
  namespace: ${kns}
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: vault
    kind: SecretStore
  target:
    name:  es-secret
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: ${kns}/demosecret

EOM


kubectl apply -f  secret-stores/${TKC_NAME}-${kns}-es.yaml -n ${kns}


kubectl get ss -n  ${kns}
kubectl get es -n  ${kns}

done


vault write auth/${TKC_NAME}/role/common-secrets \
        bound_service_account_names="*" \
        bound_service_account_namespaces="*" \
        policies=policy-common-secrets,default \
        ttl=24h

cat << EON > secret-stores/${TKC_NAME}-css.yaml 
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      auth:
        kubernetes:
          mountPath: ${TKC_NAME}
          role: common-secrets
          serviceAccountRef:
            name: vault-auth
      caProvider:
        key: vault-ca.crt
        name: vault-ca
        namespace: kube-public
        type: ConfigMap
      path: common-secrets
      server: https://vault.dev.e2open.com
      version: v2

EON

kubectl create -f  secret-stores/${TKC_NAME}-css.yaml


cat << EOH > secret-stores/${TKC_NAME}-ces.yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ClusterExternalSecret
metadata:
  name: "ces-regcred"
spec:
  externalSecretName: "ces-regcred"

  namespaceSelector:
        matchExpressions:
        - key: name
          operator: In
          values:
          - trident
          - ingress-nginx
          - falco

  refreshTime: "1m"

  externalSecretSpec:
    secretStoreRef:
      name: vault-backend
      kind: ClusterSecretStore

    refreshInterval: "1m"
    target:

      name: regcred
      creationPolicy: 'Owner'
      template:
        type: kubernetes.io/dockerconfigjson
    data:
      - secretKey: .dockerconfigjson
        remoteRef:
          key: secret/pullsecret
          property: dockerconfigjson

EOH


kubectl apply -f secret-stores/${TKC_NAME}-ces.yaml
