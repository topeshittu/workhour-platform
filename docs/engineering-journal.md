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


## Failure Simulation 1 - Web Pod Deletion

### Objective

Test whether the PostifyHQ web layer can recover automatically when one application Pod is deleted.

### Test performed

1. Listed the running PostifyHQ web Pods.
2. Deleted one web Pod manually.
3. Watched Kubernetes create a replacement Pod.
4. Verified that the Deployment returned to the desired state of 2 replicas.
5. Verified that the Service endpoint list updated to include the new Pod IP.

### Result

Before deletion, the web Pods were running normally:

```text
postifyhq-web-8487bb8dc6-bbbbw   1/1   Running   IP: 10.244.0.80
postifyhq-web-8487bb8dc6-rb2gp   1/1   Running   IP: 10.244.0.79
```

After deleting one Pod, Kubernetes created a replacement Pod:

```text
postifyhq-web-8487bb8dc6-kz48s   1/1   Running   IP: 10.244.0.82
```

The Deployment returned to the desired state:

```text
postifyhq-web   2/2
```

The EndpointSlice also updated automatically:

```text
ENDPOINTS
10.244.0.80,10.244.0.82
```

### Conclusion

The PostifyHQ web layer recovered successfully because it is managed by a Deployment with `replicas: 2`. When one Pod was deleted, the ReplicaSet detected that the actual state no longer matched the desired state and created a replacement Pod.

### Key lesson

Web Pods are disposable. Their names and IP addresses can change, but the Service remains stable and continues routing traffic to healthy Pods.

### Limitation

This test proves Pod-level self-healing. It does not prove application-level health, database availability, or zero-downtime during all types of failures.

### Production improvements

* Add a real `/health` or `/ready` endpoint.
* Replace the temporary TCP readiness probe with an HTTP readiness probe.
* Add monitoring for Pod restarts and unavailable replicas.
* Add alerts for Deployment availability below desired replica count.


## Failure Simulation 2 - MySQL Pod Deletion

### Objective
Test whether MySQL data survives Pod deletion when deployed using a StatefulSet and PVC.

### Test performed
1. Created a test table named `platform_test`.
2. Inserted a test row before deleting the MySQL Pod.
3. Deleted `postifyhq-mysql-0`.
4. Waited for the StatefulSet to recreate the Pod.
5. Queried the table again after recovery.

### Result
The MySQL Pod was recreated with the same StatefulSet identity: `postifyhq-mysql-0`.

The Pod IP changed from `10.244.0.74` to `10.244.0.83`, but the PVC remained the same:

`mysql-data-postifyhq-mysql-0`

The test row still existed after recovery.

### Conclusion
The database data survived Pod deletion because MySQL stores its data on a PersistentVolumeClaim instead of relying on the container filesystem.

### Limitation
This proves persistence, not high availability. With only one MySQL replica, the database still becomes temporarily unavailable during Pod recovery.

### Production improvements
- Add automated MySQL backups.
- Test restore from backup.
- Consider managed database service such as AWS RDS for production.
- Add monitoring for MySQL availability, storage usage, and restart count.

## Failure Simulation 3 - Missing ConfigMap Key

### Objective
Test what happens when a required ConfigMap key used by the PostifyHQ web Deployment is missing.

### Test performed
1. Removed `DB_HOST` from `postifyhq-config`.
2. Applied the updated ConfigMap.
3. Restarted the `postifyhq-web` Deployment so new Pods would read the updated ConfigMap.
4. Checked the status of the new Pods.
5. Described a failing Pod to inspect the Events section.

### Result
The new web Pods failed with:

```text
CreateContainerConfigError
