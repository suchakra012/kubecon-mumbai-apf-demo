#!/bin/bash
set -e

echo "💣 Breaking API server..."

# Create heavy load
for i in {1..25}; do
  kubectl create ns ns-$i 2>/dev/null || true
  kubectl create deployment nginx-$i \
    --image=nginx \
    --replicas=40 \
    -n ns-$i 2>/dev/null || true
done

sleep 20

# Stress
cat <<'EOF' > stress.sh
#!/bin/bash
for i in {1..70}; do
  while true; do
    kubectl get pods -A >/dev/null 2>&1
  done &
done
wait
EOF

chmod +x stress.sh
./stress.sh &

sleep 5

# Break APF
cat <<EOF | kubectl apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: PriorityLevelConfiguration
metadata:
  name: demo-breaker
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 1
    limitResponse:
      type: Reject
EOF

cat <<EOF | kubectl apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: demo-catch-all
spec:
  matchingPrecedence: 100
  priorityLevelConfiguration:
    name: demo-breaker
  rules:
  - subjects:
    - kind: User
      user:
        name: kind-apf-demo
    - kind: Group
      group:
        name: system:masters
    - kind: Group
      group:
        name: system:authenticated
    resourceRules:
    - verbs: ["get","list"]
      apiGroups: ["*"]
      resources: ["*"]
      clusterScope: true
EOF

echo "🚨 System should start failing now"
