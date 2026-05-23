## Kubernetes API Server Performance Clinic
Simulating Control Plane Overload & Recovering with API Priority and Fairness (APF)

A hands-on demo environment to simulate:

- API server overload
- 429 Too Many Requests
- Control plane saturation
- SRE panic moments 😄
- Recovery using Kubernetes API Priority & Fairness (APF)

This demo was built for a KubeCon-style live incident walkthrough where we intentionally overload the Kubernetes API server and then recover the cluster using APF.

[!IMPORTANT]  
Not to be tested in Production Environment

## 🎯 What This Demo Covers
- Create sustained API server pressure
- Generate request spikes against the Kubernetes control plane
- Observe API degradation in Grafana
- Trigger 429 Too Many Requests
- Apply API Priority & Fairness (APF)
- Protect critical admin traffic
- Restore cluster stability without reducing traffic

## 🧱 Architecture Overview

<img width="703" height="672" alt="image" src="https://github.com/user-attachments/assets/60baee97-4b8a-41d0-81c2-a2ff93dc38e3" />

## ⚙️ Prerequisites

Install:
- kind
- kubectl
- helm
- jq

**macOS**
```bash
brew install kind kubectl helm jq
```
**linux**
```bash
sudo apt install jq
```
## 🚀 Step 1 — Create kind Cluster
```bash
kind create cluster --name apf-demo
```
**Verify cluster creation**
```bash
kubectl get nodes
```

## 📊 Step 2 — Setup Monitoring Stack
**Execute**
```bash
git clone https://github.com/suchakra012/kubecon-mumbai-apf-demo.git
cd kubecon-mumbai-apf-demo
./setup-monitoring.sh
```
The grafana dashboard will be available at the public IP, where the VM is running
- http://10.x.x.x:8000/

**Navigate to the API Server APF Demo dashboard precreated with the cluster**
<img width="599" height="401" alt="image" src="https://github.com/user-attachments/assets/aa8de07a-41de-486d-abb0-e0aba50e7647" />

Initially
- “Everything looks healthy…”
- Low Requests/sec
- No API Server Requests error 429

## 💣 Step 3 — Break the Cluster
```bash
./break-cluster.sh
```

💥 **Observe Failure**
```bash
kubectl get pods
```
**Expected:**
Error from server (Too Many Requests)

Observe Grafana:

- Requests/sec spike
- 429 errors increase
- Latency spike
- Queue pressure rise

## 🛠️ Step 4 — Recover with APF
```bash
./fix-apf.sh
```

✅ **Observe Recovery**

```bash
kubectl get pods
```
**Expected**:
Pods list successfully

Observe Grafana:

- 429 stabilizes
- Latency drops
- Queue pressure normalizes
- API requests continue

## 🧹 Cleanup
**Force delete demo namespaces**
```bash
kubectl get ns | grep '^ns-' | awk '{print $1}' | xargs -I {} kubectl delete ns {} --force --grace-period=0
```

🧠 **Key Takeaways**
- Kubernetes API server is a shared resource
- Not all requests deserve equal priority
- APF protects critical traffic during overload
- Queueing is often better than rejection
- Observability is essential for control plane debugging
- API fairness matters in multi-tenant clusters










