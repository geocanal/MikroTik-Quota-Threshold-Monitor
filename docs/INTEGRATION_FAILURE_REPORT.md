# Integration Failure Report

**Environment:** Production (`203.0.113.10:550`)  
**Generated:** 2026-10-03 16:15 UTC  

---

### Failure 1: RouterOS Outbound Telemetry Pipeline Stalled
- **Component Affected:** Router-to-Server Ingestion (`mikrotik/wan-usage`, `mikrotik/wan-quality`, `mikrotik/hotspot-telemetry`).
- **Exact Observation:**
  The server-side ingestion infrastructure is 100% operational (n8n webhooks responding HTTP 200, PostgreSQL database accepting writes, Grafana and Telegram bot fully connected). However, the latest telemetry rows received in `campaign_db` are dated:
  - `mikrotik_wan_readings`: `2026-09-30 17:35:23 UTC` (~3 days ago)
  - `mikrotik_wan_quality`: `2026-09-30 17:37:27 UTC` (~3 days ago)
  - `hotspot_user_telemetry`: `2026-09-30 17:35:23 UTC` (~3 days ago)
- **Reproduction Steps:**
  1. Query `campaign_db`: `SELECT MAX(probed_at) FROM mikrotik_wan_quality;`.
  2. Compare against current host timestamp: `date -u`.
  3. Difference exceeds 68 hours.
- **Root Cause Analysis:**
  The server migrated recently or experienced host address changes (`148.251.139.248` -> `203.0.113.10`). While domain `n8n.example.com` correctly points to `203.0.113.10`, the MikroTik router's internal DNS cache or schedulers on the router (`send-wan-telemetry`, `send-wan-quality`, `hotspot_telemetry`) either:
  1. Were disabled or paused.
  2. Are encountering DNS resolution timeouts from the router's DNS server for `n8n.example.com`.
  3. Require manual re-trigger via `/system script run send-wan-quality`.
- **Impact:**
  Grafana dashboards and Telegram bot display historical figures instead of live real-time meters until the router resumes pushes.
- **Proposed Fix:**
  Execute a manual run of `send-wan-quality` and `send-wan-telemetry` on the router, or flush DNS cache on MikroTik (`/ip dns cache flush`).
- **Verification Procedure:**
  Query `SELECT MAX(probed_at) FROM mikrotik_wan_quality;` to verify a timestamp from within the last 5 minutes.
