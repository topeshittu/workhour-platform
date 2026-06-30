## PostifyHQ Kubernetes Deployment - Local Minikube

### What was deployed
- Namespace: postifyhq
- ConfigMap: postifyhq-config
- Secret: postifyhq-secret
- MySQL StatefulSet: postifyhq-mysql
- MySQL Headless Service: postifyhq-mysql
- MySQL PVC: mysql-data-postifyhq-mysql-0
- Web Deployment: postifyhq-web
- Web Service: postifyhq-web
- Ingress: postifyhq-web

### Key issues encountered
1. HTTP readiness probe against `/` failed because the app returned `302`.
2. Changed readiness probe temporarily to TCP port check.
3. `/etc/hosts` with `192.168.49.2 postifyhq.local` did not work on macOS Docker driver.
4. `127.0.0.1 postifyhq.local` hit Laravel Herd on port 80.
5. Port-forwarding the ingress controller to port 8081 correctly routed traffic to Kubernetes.

### Current access method
```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8081:80
curl -I -H "Host: postifyhq.local" http://localhost:8081
