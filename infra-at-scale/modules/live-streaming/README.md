# modules/live-streaming

RTP-push ingest → MediaLive transcode → S3 (HLS) → CloudFront playback,
matching the "Live Streaming Pipeline" swimlane in the architecture diagram.

## About the diagram's "SRT Ingest" label

The diagram calls for SRT ingest specifically. This module ships **RTP_PUSH**
instead, and that's a deliberate, verified substitution, not an oversight:
neither `aws_medialive_input`'s SRT settings nor an SRT-capable MediaConnect
resource exist in the pinned `hashicorp/aws` provider version — confirmed by
inspecting `terraform providers schema -json` for both `aws_medialive_input`
and any `aws_mediaconnect_*` resource, neither of which is present. RTP_PUSH
is the nearest input type this provider version can actually provision.

If you need true SRT ingest before the provider adds support:

1. Configure the MediaLive input for SRT manually via the AWS Console or CLI
   (`aws medialive create-input --type SRT_CALLER ...`), then
   `terraform import` it into `aws_medialive_input.ingest` and switch this
   module's `type` accordingly once your provider version supports the
   matching schema — re-check with the same `providers schema -json`
   inspection before trusting any AI- or docs-suggested block names here;
   this corner of the provider has moved across versions.
2. Or front MediaLive with a MediaConnect SRT listener flow once
   `aws_mediaconnect_flow` (or equivalent) ships in a provider release,
   feeding MediaLive via the `media_connect_flows` input attachment instead
   of a direct push input.

## Before applying

- **`input_cidr_allowlist`** is a placeholder (`203.0.113.0/24`, RFC 5737
  TEST-NET-3) — replace with the encoder's real public egress CIDR. Only
  those source IPs may push into `aws_medialive_input.ingest`.
- **Where the encoder pushes to**: MediaLive assigns the actual host:port
  after `apply` — read it from the AWS Console (MediaLive → Inputs) or `aws
  medialive describe-input`; it isn't a Terraform-configurable value.
- **The encode ladder is a single 720p rendition** (`video_descriptions` /
  `outputs` in `aws_medialive_channel.this`). Real adaptive-bitrate delivery
  needs multiple renditions (e.g. 1080p/720p/480p/360p) — duplicate the
  `video_descriptions` and `outputs` blocks per rendition, each referencing a
  distinct bitrate/resolution, once you know the source signal's real
  characteristics and target bitrate budget.
- MediaLive channels bill **per hour while running**, independent of whether a
  signal is actually connected. Start/stop is intentionally not automated by
  Terraform (`aws_medialive_channel` has no "desired state: running" toggle
  here) — start it via the console/CLI/CI job only when an event is live, and
  stop it immediately after.
