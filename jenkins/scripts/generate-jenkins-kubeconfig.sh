#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-postifyhq}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-jenkins-deployer}"
SECRET_NAME="${SECRET_NAME:-jenkins-deployer-token}"
OUTPUT_FILE="${OUTPUT_FILE:-jenkins-deployer-kubeconfig.yaml}"

echo "Generating Jenkins kubeconfig for Minikube..."

CURRENT_SERVER="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"

if [[ -z "$CURRENT_SERVER" ]]; then
  echo "ERROR: Could not detect current Kubernetes API server from kubectl config."
  exit 1
fi

API_PORT="$(echo "$CURRENT_SERVER" | sed -E 's#https://127\.0\.0\.1:([0-9]+)#\1#')"

if [[ "$API_PORT" == "$CURRENT_SERVER" || -z "$API_PORT" ]]; then
  echo "ERROR: Could not extract Minikube API port from: $CURRENT_SERVER"
  echo "Expected format: https://127.0.0.1:<port>"
  exit 1
fi

echo "Detected Minikube API port: $API_PORT"

kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" >/dev/null

TOKEN="$(kubectl get secret "$SECRET_NAME" \
  -n "$NAMESPACE" \
  -o jsonpath='{.data.token}' | base64 -d)"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Could not read token from secret $SECRET_NAME in namespace $NAMESPACE."
  exit 1
fi

cat > "$OUTPUT_FILE" <<EOF
apiVersion: v1
kind: Config
clusters:
- name: minikube
  cluster:
    insecure-skip-tls-verify: true
    server: https://host.docker.internal:${API_PORT}
contexts:
- name: jenkins-deployer@minikube
  context:
    cluster: minikube
    namespace: ${NAMESPACE}
    user: ${SERVICE_ACCOUNT}
current-context: jenkins-deployer@minikube
users:
- name: ${SERVICE_ACCOUNT}
  user:
    token: ${TOKEN}
EOF

chmod 600 "$OUTPUT_FILE"

echo "Generated: $OUTPUT_FILE"
echo "Server: https://host.docker.internal:${API_PORT}"
echo
echo "Next steps:"
echo "1. Upload $OUTPUT_FILE to Jenkins as Secret file credential."
echo "2. Credential ID should remain: minikube-jenkins-deployer-kubeconfig"
echo "3. Test Jenkins Kubernetes access again."
