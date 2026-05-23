#!/bin/bash
set -e

echo "📊 Installing monitoring stack..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create ns monitoring 2>/dev/null || true

helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring

echo "⏳ Waiting for Grafana..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=grafana \
  -n monitoring --timeout=180s

# Get Grafana password
PASS=$(kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "🔐 Grafana password: $PASS"

echo "🌐 Port forwarding Grafana..."
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80 &

sleep 5

echo "📥 Importing Dashboard..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: apf-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  apf-dashboard.json: |
    {
      "title": "API Server APF Demo",
      "panels": [
        {
          "type": "timeseries",
          "title": "Requests/sec",
          "targets": [
            {
              "expr": "sum(rate(apiserver_request_total[1m]))"
            }
          ]
        },
        {
          "type": "timeseries",
          "title": "429 Errors 🔥",
          "targets": [
            {
              "expr": "sum(rate(apiserver_request_total{code=\"429\"}[1m]))"
            }
          ]
        },
        {
          "type": "timeseries",
          "title": "Latency P99",
          "targets": [
            {
              "expr": "histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket[1m])) by (le))"
            }
          ]
        },
        {
          "type": "timeseries",
          "title": "APF Rejections",
          "targets": [
            {
              "expr": "sum(rate(apiserver_flowcontrol_rejected_requests_total[1m]))"
            }
          ]
        },
        {
          "type": "timeseries",
          "title": "APF Queue",
          "targets": [
            {
              "expr": "sum(apiserver_flowcontrol_current_inqueue_requests)"
            }
          ]
        }
      ]
    }
EOF

echo "✅ Dashboard installed!"
echo "👉 Open http://localhost:3000"
echo "👉 user: admin | password: $PASS"
