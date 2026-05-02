# ==========================================
# MOMO RADIO - TEST OVERRIDES (values-test.yaml)
# ==========================================

# 1. GLOBAL APP CONFIG (Dummy values for testing)
config:
  storage:
    provider: "s3"
    endpoint: "https://s3.example.com"
    region: "us-east-1"
    keyId: "test-key-id"
    bucketIngest: "test-ingest"
    bucketProd: "test-prod"
    bucketStreamLive: "test-live"
    bucketMaster: "test-master"
  server:
    pollingInterval: 10
    tempDir: "/tmp/test"
    timezone: "UTC"
  database:
    host: "localhost"
    port: 5432
    user: "test_user"
    name: "test_db"
  redis:
    host: "localhost"
    port: 6379

# 2. SECRET MANAGEMENT (Manual mode for testing)
secrets:
  external:
    enabled: false # Disable Cloud Secret Manager for testing
  manual:
    enabled: true  # Enable local secret generation
    data:
      RADIO_DATABASE_PASSWORD: "test_password"
      RADIO_STORAGE_APP_KEY: "test_s3_key"
      RADIO_REDIS_PASSWORD: "test_redis_password"
      RADIO_SERVICES_DISCOGS_TOKEN: "test_discogs_token"

# 3. COMPONENT OVERRIDES
server:
  replicaCount: 1
  pdb: { enabled: false }
  autoscaling: { enabled: false }
  image:
    repository: ghcr.io/sudo-bngz/momo-radio-api
    tag: "latest"

worker:
  replicaCount: 1
  concurrency: 2
  pdb: { enabled: false }
  autoscaling: { enabled: false }
  keda: { enabled: false } # Disable KEDA to avoid CRD errors in test
  image:
    repository: ghcr.io/sudo-bngz/momo-radio-worker
    tag: "latest"

streamer:
  replicaCount: 1
  image:
    repository: ghcr.io/sudo-bngz/momo-radio-streamer
    tag: "latest"

# 4. INFRASTRUCTURE DISABLES (Testing via Port-Forward)
ingress:
  enabled: false

metrics:
  enabled: false

networkPolicy:
  enabled: false
