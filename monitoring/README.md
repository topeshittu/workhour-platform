## Monitoring and Alerting

This platform includes a Kubernetes monitoring foundation using Prometheus, Grafana, Alertmanager, kube-state-metrics, and node-exporter.

The monitoring stack is deployed into the `monitoring` namespace using the `kube-prometheus-stack` Helm chart.

### Components

```text
Prometheus          → collects and stores metrics
Grafana             → visualizes metrics through dashboards
Alertmanager        → handles alert routing and notification flow
kube-state-metrics  → exposes Kubernetes object-state metrics
node-exporter       → exposes node/host-level metrics
PrometheusRule      → defines alerting rules
ServiceMonitor      → tells Prometheus what services to scrape
```

### Monitoring Architecture

```text
Kubernetes workloads
  ↓
kube-state-metrics / node-exporter
  ↓
Kubernetes Services
  ↓
ServiceMonitor resources
  ↓
Prometheus Operator
  ↓
Prometheus scrape targets
  ↓
PromQL queries
  ↓
Grafana dashboards + Prometheus alert rules
  ↓
Alertmanager
```

### What Was Verified

The monitoring foundation was verified by confirming:

```text
Prometheus pod running
Grafana pod running
Alertmanager pod running
Prometheus Operator running
kube-state-metrics running
node-exporter running
Prometheus custom resource ready
Alertmanager custom resource ready
ServiceMonitors created
Grafana accessible locally
Prometheus accessible locally
Kubernetes metrics available
Node metrics available
```

Prometheus queries used for verification:

```promql
up
```

```promql
kube_pod_status_phase
```

```promql
node_cpu_seconds_total
```

### PostifyHQ Availability Alert

A custom PrometheusRule was added for PostifyHQ:

```text
Alert: PostifyHQWebReplicasUnavailable
Namespace: monitoring
Rule file: monitoring/postifyhq-prometheusrule.yaml
```

The alert detects when the PostifyHQ web deployment has fewer available replicas than desired:

```promql
kube_deployment_status_replicas_available{namespace="postifyhq", deployment="postifyhq-web"}
  <
kube_deployment_spec_replicas{namespace="postifyhq", deployment="postifyhq-web"}
```

This alert helps detect degraded application availability.

### Alert Test

The alert was tested with a controlled local failure simulation:

```text
1. Cordon the Minikube node.
2. Scale PostifyHQ web replicas from 2 to 3.
3. Keep the existing 2 healthy replicas running.
4. Force the third replica to remain unavailable.
5. Confirm available replicas are below desired replicas.
6. Wait for the alert to fire.
7. Recover the deployment and confirm the alert clears.
```

Result:

```text
Alert state before recovery: firing
Alert state after recovery: inactive
Time to fire: 5 minutes
Alert cleared after recovery: yes
```

### Recovery Commands Used

```bash
kubectl scale deployment postifyhq-web --replicas=2 -n postifyhq
kubectl uncordon minikube
kubectl rollout status deployment/postifyhq-web -n postifyhq --timeout=120s
```

Final recovery state:

```text
postifyhq-web: 2/2 Ready
minikube: Ready
PrometheusRule: present
```

### Grafana Dashboard Inspection

A Kubernetes compute dashboard was inspected for the `postifyhq` namespace:

```text
Dashboard: Kubernetes / Compute Resources / Namespace (Pods)
Panel: CPU Usage
```

The panel uses PromQL metrics such as:

```promql
node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m
```

This dashboard helps identify abnormal pod CPU usage after traffic spikes, inefficient queries, bad deployments, infinite loops, or runaway background jobs.

### Key Lessons

```text
A metric is raw time-series data.
A PromQL query turns metrics into useful signals.
A Grafana panel visualizes a query.
An alert rule evaluates a query over time and detects a problem.
Alertmanager routes notifications after Prometheus fires alerts.
```

Operational distinction:

```text
Available replicas below desired replicas = availability risk
Stuck rollout while old pods still serve traffic = release risk
High CPU or high memory = saturation/performance risk
```

### Future Improvements

```text
Add rollout-stuck alert
Add high CPU and high memory alerts for PostifyHQ
Configure Alertmanager notification routing
Test alert delivery through email or webhook
Add application-level metrics
Add blackbox probing for HTTP endpoint health
Add centralized logging with Loki or another log aggregation tool
```

