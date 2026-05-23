#!/bin/bash
set -e

echo "🛠️ Applying APF Recovery (v1 compatible)..."

# -------------------------------
# 1. Remove breaker config
# -------------------------------
echo "🧹 Cleaning previous configs..."

kubectl delete flowschema demo-catch-all 2>/dev/null || true
kubectl delete prioritylevelconfiguration demo-breaker 2>/dev/null || true

sleep 2

# -------------------------------
# 2. High Priority (Admins)
# -------------------------------
echo "🟢 Creating HIGH priority lane..."

cat <<EOF | kubectl apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: PriorityLevelConfiguration
metadata:
  name: high-priority
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 50
    limitResponse:
      type: Queue
      queuing:
        queues: 64
        handSize: 8
        queueLengthLimit: 50
EOF

# -------------------------------
# 3. Low Priority (Default Traffic)
# -------------------------------
echo "🔴 Creating LOW priority lane..."

cat <<EOF | kubectl apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: PriorityLevelConfiguration
metadata:
  name: low-priority
spec:
  type: Limited
  limited:
    nominalConcurrencyShares: 5
    limitResponse:
      type: Reject
EOF

# -------------------------------
# 4. Admin Protection (CRITICAL)
# -------------------------------
echo "🛡️ Protecting admin traffic..."

cat <<EOF | kubectl apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: admin-protected
spec:
  matchingPrecedence: 900
  priorityLevelConfiguration:
    name: high-priority
  rules:
  - subjects:
    - kind: Group
      group:
        name: system:masters
    resourceRules:
    - verbs: ["*"]
      apiGroups: ["*"]
      resources: ["*"]
      clusterScope: true
EOF

# -------------------------------
# 5. Default Traffic Throttling
# -------------------------------
echo "⚖️ Applying fairness to remaining traffic..."

cat <<EOF | kubectl apply -f -
apiVersion: flowcontrol.apiserver.k8s.io/v1
kind: FlowSchema
metadata:
  name: default-throttled
spec:
  matchingPrecedence: 100
  priorityLevelConfiguration:
    name: low-priority
  rules:
  - subjects:
    - kind: Group
      group:
        name: system:authenticated
    resourceRules:
    - verbs: ["get","list"]
      apiGroups: ["*"]
      resources: ["*"]
      clusterScope: true
EOF

# -------------------------------
# 6. Verification
# -------------------------------
echo ""
echo "✅ APF FIX APPLIED SUCCESSFULLY"
echo "----------------------------------------"
echo "Verify:"
echo "kubectl get pods"
echo ""
echo "Metrics:"
echo "kubectl get --raw /metrics | grep flowcontrol"
echo "----------------------------------------"
echo "🎯 Same load, but system should now be stable"
