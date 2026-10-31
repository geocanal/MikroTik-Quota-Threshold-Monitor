# E2E Flow Matrix

**Environment:** Production (`203.0.113.10:550`)  
**Generated:** 2026-10-03 16:15 UTC  

| Flow | Trigger | Dependencies | Expected Result | Observed Result | Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **WAN Usage Telemetry** | RouterOS 5m Scheduler (`/tool fetch`) | n8n (`PPAQLTX0UUv4OnZl`), PostgreSQL (`app-postgres-1`) | Store raw counters in `mikrotik_wan_readings`, calculate deltas in `mikrotik_wan_usage`, detect reboots | Pipeline active and validated with 5,884 historical readings; idle since Sept 30 | **DEGRADED** |
| **WAN Quality Probes** | RouterOS 2m Scheduler (`send-wan-quality`) | n8n (`mikrotik-wan-quality-monitor`), PostgreSQL (`app-postgres-1`) | Store latency, min/max RTT, packet loss in `mikrotik_wan_quality` | Pipeline active; 2,552 probes stored; idle since Sept 30 17:37 UTC | **DEGRADED** |
| **Hotspot User Tracking** | RouterOS 5m Scheduler (`hotspot_telemetry.rsc`) | n8n (`jmKSudrEOTTyKT5Y`), PostgreSQL (`app-postgres-1`) | Stream active user sessions and byte limits to `hotspot_user_telemetry` | Pipeline active; 6,344 records stored; 0 orphans; idle since Sept 30 | **DEGRADED** |
| **Interactive Telegram Control** | Telegram User Message / Inline Button Click | `mikrotik-telegram-bot.service`, PostgreSQL, Telegram Bot API | Instant response with live dashboard, latency check, or outage log | Bot polling cleanly; receives command and replies in <1 second; verified | **PASS** |
| **Quota Burn & SLA Evaluation** | SQL View Execution & Database Triggers | PostgreSQL Views (`view_mikrotik_wan_quota_status`) | Continuous calculation of burn rates, projected exhaustion dates, remaining GB | Calculations verified: WAN1 at 37.2%, WAN2 at 100.0%, SLA Uptime at 99.79% | **PASS** |
| **Grafana Real-time Observability**| Browser Dashboard Load / Auto-refresh (1m) | `mikrotik-grafana`, PostgreSQL datasource `PCC52D03280B7034C` | Render 12 live panels (time-series, gauges, bars, tables) without connection errors | Healthcheck OK; all 12 queries return structured data successfully | **PASS** |
| **Outage Forensic & Email Escalation**| ISP Line Down Detection / Manual Trigger | PostgreSQL (`wan_outage_events`), SMTP / External Mail API | Record outage duration, verify power uptime, dispatch claim to ISP support email | 1 real event documented on Vodafone DSL (90 min downtime) and dispatched | **PASS** |
| **Safe WAN Isolation & PBR Override**| Telegram Bot Button / n8n Trigger | RouterOS Mangle Rules, PBR Tables (`to_wan1`, `to_wan2`) | Disable PCC rule for exhausted WAN, flush scoped connections, preserve monitoring | Script `wan_control_pbr.rsc` verified with strict invariants; no accidental triggers | **PASS** |
