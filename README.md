# Momo Radio Chart

A Helm chart for Momo Radio, a scalable, containerized radio streaming platform and DJ backend.

Source code can be found here:

* [https://github.com/sudo-bngz/momo-radio-api](https://github.com/sudo-bngz/momo-radio)


This chart installs the Momo Radio backend suite. The architecture is split into three highly decoupled components to allow independent scaling:
1. **Server**: The public-facing API and web UI.
2. **Worker**: Background job processing (audio analysis, metadata extraction) powered by Asynq.
3. **Streamer**: The continuous HLS live audio broadcast process (FFmpeg).

> **Note:**
> Sensitive configuration (such as database credentials, Redis passwords, and S3 access keys) are not managed directly in `values.yaml`. You must pre-provision a Kubernetes Secret (default name: `momo-radio-secret`) using your preferred tool (e.g., ExternalSecrets, SealedSecrets) and reference it via `envFromSecret`.

## Scaling and High Availability

Because Momo Radio handles varying workloads, the components scale using different strategies. 

> **Warning:**
> The `streamer` deployment must **always** remain at exactly 1 replica to prevent multiple FFmpeg instances from colliding and corrupting the HLS stream chunks.

### API Autoscaling (HPA)

The web server utilizes standard Horizontal Pod Autoscaling based on CPU and Memory.

```yaml
server:
  replicaCount: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 80
```

### Worker Autoscaling (KEDA)

Audio processing is highly CPU-bound. Instead of relying on reactive CPU metrics, the worker utilizes **KEDA** to scale proactively based on the exact number of jobs pending in the Redis queue. It can also scale to zero when idle to save compute costs.

```yaml
worker:
  replicaCount: 0 # Scales to 0 when idle
  autoscaling:
    enabled: false # Must be false to prevent conflicts with KEDA
  keda:
    enabled: true
    minReplicas: 0
    maxReplicas: 5
    redis:
      address: "your-redis-host:6379"
      passwordSecretKey: "REDIS_PASSWORD"
      queues:
        - name: "asynq:{exports}:pending"
          targetLength: "3"
```

## Ingress configuration

The chart is configured to work out-of-the-box with NGINX Ingress and Cert-Manager. 

> **Note:**
> Ensure that `proxy-body-size` is large enough to accept full-length DJ mix uploads.

```yaml
ingress:
  enabled: true
  className: "nginx"
  host: "api.momoradio.com"
  tls:
    enabled: true
    secretName: "momo-radio-tls"
    clusterIssuer: "letsencrypt-prod"
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
```

## Zero-Trust Security

If you enable `networkPolicy.enabled: true`, the chart creates strict firewall rules. The `worker` and `streamer` will reject all inbound cluster traffic except for Prometheus metrics scraping. The `server` will only accept traffic from your defined Ingress controller.

## Prerequisites

- Kubernetes: `>=1.22.0-0`
- Helm v3.0.0+
- Redis (For Asynq background jobs)
- [Optional] KEDA (For queue-based worker autoscaling)
- [Optional] Prometheus Operator (For ServiceMonitors)

## Installing the Chart

To install the chart with the release name `momo-radio`:

```console
$ helm repo add momo-radio https://sudo-bngz.github.io/momo-radio-helm/
"momo-radio" has been added to your repositories

$ helm install momo-radio momo-radio/momo-radio
NAME: momo-radio
...
```

## Global Configs

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| envFromSecret | string | `"momo-radio-secret"` | Name of the pre-existing Kubernetes Secret containing sensitive environment variables (DB_DSN, REDIS_URL, etc.) |

## Momo Radio Server (API/UI)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| server.enabled | bool | `true` | Enable the API/Web Server |
| server.replicaCount | int | `2` | Initial number of server pods |
| server.port | int | `8080` | Internal container port for the HTTP server |
| server.command | list | `[]` | Override the default Docker container startup command |
| server.image.repository | string | `"ghcr.io/sudo-bngz/momo-radio-api"` | Docker image repository for the server |
| server.image.tag | string | `"latest"` | Docker image tag for the server |
| server.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| server.resources | object | See values.yaml | Resource limits and requests for the server pods |
| server.pdb.enabled | bool | `true` | Deploy a PodDisruptionBudget for high availability during cluster maintenance |
| server.pdb.maxUnavailable | int | `1` | Number of pods allowed to be unavailable during eviction |
| server.autoscaling.enabled | bool | `true` | Enable Horizontal Pod Autoscaler (HPA) |
| server.autoscaling.minReplicas | int | `2` | Minimum HPA replicas |
| server.autoscaling.maxReplicas | int | `10` | Maximum HPA replicas |
| server.autoscaling.targetCPUUtilizationPercentage | int | `80` | Target CPU utilization for scaling |

## Momo Radio Worker

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| worker.enabled | bool | `true` | Enable the background job worker |
| worker.replicaCount | int | `1` | Initial number of worker pods (Overridden by KEDA if enabled) |
| worker.command | list | `[]` | Override the default Docker container startup command |
| worker.image.repository | string | `"ghcr.io/sudo-bngz/momo-radio-worker"` | Docker image repository for the worker |
| worker.image.tag | string | `"latest"` | Docker image tag for the worker |
| worker.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| worker.resources | object | See values.yaml | Resource limits and requests (Typically requires high CPU) |
| worker.pdb.enabled | bool | `true` | Deploy a PodDisruptionBudget for the worker |
| worker.pdb.maxUnavailable | int | `1` | Number of pods allowed to be unavailable during eviction |
| worker.autoscaling.enabled | bool | `false` | Enable standard HPA (Disable this if using KEDA) |
| worker.keda.enabled | bool | `true` | Enable KEDA event-driven autoscaling based on Redis queue depth |
| worker.keda.minReplicas | int | `0` | Minimum replicas (Scale to zero supported) |
| worker.keda.maxReplicas | int | `5` | Maximum worker pods |
| worker.keda.redis.address | string | `"your-redis-host:6379"` | Internal cluster address for Redis |
| worker.keda.redis.passwordSecretKey | string | `"REDIS_PASSWORD"` | The key inside `envFromSecret` containing the Redis password |
| worker.keda.redis.queues | list | See values.yaml | List of Asynq queues and their target lengths for scaling |

## Momo Radio Streamer

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| streamer.enabled | bool | `true` | Enable the live HLS streaming process |
| streamer.replicaCount | int | `1` | STRICTLY 1. Prevents duplicate audio streams from corrupting the HLS output. |
| streamer.command | list | `[]` | Override the default Docker container startup command |
| streamer.image.repository | string | `"ghcr.io/sudo-bngz/momo-radio-streamer"` | Docker image repository for the streamer |
| streamer.image.tag | string | `"latest"` | Docker image tag for the streamer |
| streamer.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy |
| streamer.resources | object | See values.yaml | Resource limits and requests for FFmpeg encoding |

## Ingress

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| ingress.enabled | bool | `true` | Enable the Ingress resource |
| ingress.className | string | `"nginx"` | Defines which ingress controller will implement the resource |
| ingress.host | string | `"api.momoradio.com"` | Primary domain for the API |
| ingress.tls.enabled | bool | `true` | Enable TLS configuration |
| ingress.tls.secretName | string | `"momo-radio-tls"` | Name of the TLS secret to be generated by Cert-Manager |
| ingress.tls.clusterIssuer | string | `"letsencrypt-prod"` | Cert-Manager ClusterIssuer name |
| ingress.annotations | object | See values.yaml | Additional ingress annotations (e.g. proxy-body-size) |

## Metrics & Network Security

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| metrics.enabled | bool | `true` | Expose port 9091 and headless services for Prometheus scraping |
| metrics.serviceMonitor.enabled | bool | `true` | Deploy a Prometheus ServiceMonitor resource |
| metrics.serviceMonitor.interval | string | `"15s"` | Scrape interval |
| metrics.serviceMonitor.labels | object | `{"release": "prometheus"}` | Required labels for your Prometheus Operator to discover the monitor |
| networkPolicy.enabled | bool | `true` | Deploy Zero-Trust Kubernetes NetworkPolicies |
| networkPolicy.ingressController.namespaceLabels | object | See values.yaml | Labels identifying the namespace of your Ingress Controller |
| networkPolicy.ingressController.podLabels | object | See values.yaml | Labels identifying the pods of your Ingress Controller |
| networkPolicy.prometheus.namespaceLabels | object | See values.yaml | Labels identifying the namespace of your Prometheus instance |
| networkPolicy.prometheus.podLabels | object | See values.yaml | Labels identifying the pods of your Prometheus instance |