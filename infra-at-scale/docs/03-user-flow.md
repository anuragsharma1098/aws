# User flow

Everything in `01-git-to-deployment-flow.md` and `02-module-connections.md`
exists to serve four kinds of real traffic. This doc walks each one from the
user's side of the wire.

## 1. A visitor loads the frontend

```mermaid
sequenceDiagram
    actor U as User
    participant R53 as Route 53
    participant CF as CloudFront
    participant WAF as WAF (CLOUDFRONT scope)
    participant S3 as S3 (frontend bucket)

    U->>R53: resolve www.<domain>
    R53-->>U: CloudFront distribution's domain
    U->>CF: GET / (HTTPS)
    CF->>WAF: evaluate request
    WAF-->>CF: allow (managed rules + rate limit passed)
    alt cached at edge
        CF-->>U: cached response
    else cache miss
        CF->>S3: GetObject via Origin Access Control
        S3-->>CF: object (bucket has no public access of its own)
        CF-->>U: response, now cached
    end
```

The S3 bucket (`modules/s3-cloudfront`) is never reachable directly — it has
`block_public_acls`/`block_public_policy` on and a bucket policy that only
trusts requests carrying CloudFront's own service-principal signature scoped
to *this* distribution's ARN. Every response is also forced through
`viewer_protocol_policy = "redirect-to-https"`, so there's no plain-HTTP path
to the frontend at all.

## 2. A visitor calls the API

```mermaid
sequenceDiagram
    actor U as User
    participant R53 as Route 53
    participant WAF as WAF (REGIONAL scope)
    participant ALB as ALB (:443, backend listener)
    participant ECS as ECS task (backend, private subnet)
    participant PROXY as RDS Proxy
    participant RDS as RDS Postgres primary/replica
    participant REDIS as ElastiCache Redis

    U->>R53: resolve app.<domain>
    R53-->>U: ALB's DNS name
    U->>WAF: GET /api/... (HTTPS, via ALB)
    WAF-->>ALB: allow (managed rules + rate limit passed)
    ALB->>ECS: forward to the active (blue or green) target group
    ECS->>REDIS: cache read (session/hot data)
    alt cache hit
        REDIS-->>ECS: cached value
    else cache miss
        ECS->>PROXY: query
        PROXY->>RDS: multiplexed connection\n(writes: primary, reads: replica)
        RDS-->>PROXY: rows
        PROXY-->>ECS: rows
        ECS->>REDIS: populate cache
    end
    ECS-->>ALB: response
    ALB-->>U: response
```

Nothing in this path has a public IP except the ALB and NAT Gateways. The ECS
task, RDS Proxy, RDS instances, and Redis are all in private subnets,
security-group-scoped so that each tier can only be reached from the tier
directly above it (`modules/security-groups`) — a compromised ECS task can
reach the database, but nothing on the internet can reach the database
directly, and nothing can skip the proxy to hit RDS instances by IP from
outside the VPC.

## 3. An operator uses the admin service

Same shape as the API flow, but on a separate ALB listener
(`:8443`, `modules/alb`'s `services.admin` entry) with its own blue/green
target-group pair, its own ECS service, and its own IAM task role
(`modules/iam-ecs`, instantiated twice) — a credential or code issue in the
admin service has no path into the backend service's task role or vice
versa. The admin service intentionally has no ElastiCache wiring (it doesn't
need a cache) and isn't included in `monitoring`'s CodeDeploy auto-rollback
alarms (its rollback trigger is deployment failure only, not customer-facing
error-rate — see `02-module-connections.md`).

## 4. A viewer watches a live stream

```mermaid
sequenceDiagram
    participant ENC as Venue encoder
    participant ML as MediaLive
    participant S3 as S3 (HLS bucket)
    participant CF as CloudFront (live distribution)
    actor V as Viewer

    ENC->>ML: RTP push (from an allow-listed source IP)
    loop every hls_segment_length_seconds
        ML->>S3: write .ts segment + updated .m3u8 manifest
    end
    V->>CF: GET live.<domain>/live/index.m3u8
    CF->>S3: GetObject (OAC, cache policy tuned for live TTLs)
    S3-->>CF: manifest/segments
    CF-->>V: HLS playback
```

This pipeline is intentionally decoupled from the VPC that serves 1 and
2 — MediaLive talks to S3 over AWS's own network, not through the app VPC's
NAT Gateway, so a live event's ingest traffic can't affect API/database
capacity and vice versa. It's also the one part of the stack that isn't
always running: MediaLive channels bill hourly whether or not a signal is
connected, so the channel is started/stopped per event rather than left on
(see `modules/live-streaming/README.md`).

## 5. What a user experiences during a deployment

This is the point of the whole blue/green setup: **nothing**, if it goes to
plan.

```mermaid
sequenceDiagram
    actor U as User
    participant ALB as ALB Listener
    participant BLUE as Blue target group (old version)
    participant GREEN as Green target group (new version)

    Note over BLUE: Currently serving 100% of traffic
    Note over GREEN: New task set starting, not yet receiving traffic
    GREEN-->>GREEN: health checks pass
    Note over ALB: CodeDeploy shifts traffic per deployment_config_name
    par during the shift
        ALB->>BLUE: shrinking share of requests
        ALB->>GREEN: growing share of requests
    end
    U->>ALB: request, at any point during the shift
    ALB-->>U: response from whichever target group\nit routed to - both are healthy, both are correct
    Note over BLUE: Terminated after termination_wait_time_minutes\nonce green is fully healthy
```

A user's request never hits a target group that hasn't passed its own health
checks (`modules/alb`'s `health_check` block on both target groups), and if
CloudWatch alarms fire mid-rollout (elevated 5xx, unhealthy hosts —
`modules/monitoring`), CodeDeploy reverts the listener back to the "blue"
target group automatically, before most users would notice a degraded
version was ever live. The one moment this isn't fully invisible: `staging`
and `prod` deploys shift gradually (`ECSLinear10PercentEvery1Minutes` /
`ECSCanary10Percent15Minutes`), so a small percentage of users are on the new
version before everyone is — by design, so a bad deploy affects 10% of
traffic for a few minutes, not 100% of traffic immediately.
