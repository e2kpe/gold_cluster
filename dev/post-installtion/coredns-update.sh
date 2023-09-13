kubectl  delete cm -n kube-system coredns
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  Corefile: |
    cluster.local:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf {
           max_concurrent 1000
        }
        cache 30
        loop
        reload
        loadbalance
    }
    .:53 {
        cache 30
        reload
        forward . 10.120.127.131 10.120.127.130 {
                except cluster.local
                }
        loadbalance
 
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system

EOF
