# Service Health Matrix

**Environment:** Production OCI (`198.51.100.25` / `oci`)  
**Generated:** 2026-10-31 07:40 UTC  

| Component | Running | Connected | Functional | Evidence | Status |
| :--- | :---: | :---: | :---: | :--- | :---: |
| **mikrotik-grafana** | YES | YES | YES | Port 3000 open, `/api/health` 200 OK (`version 13.2.3`), 14 dashboard panels active | **PASS** |
| **wccp-postgres** | YES | YES | YES | Accepting connections on `127.0.0.1:55432`, 13,544 WAN readings + 74,304 Hotspot records stored | **PASS** |
| **n8n-postgres** | YES | YES | YES | Accepting connections, workflows persisted and active | **PASS** |
| **wccp-redis** | YES | YES | YES | Internal container network, healthy with 3+ weeks uptime | **PASS** |
| **n8n Core Service** | YES | YES | YES | Port 5678, `/healthz` returns `{"status":"ok"}`, active workflows loaded | **PASS** |
| **Telegram Bot Daemon** | YES | YES | YES | `mikrotik-telegram-bot.service` active (PID 2398631, 1w+ uptime), 0 webhook conflicts, 0 pending updates | **PASS** |
| **WAN Usage Telemetry Stream** | YES | YES | YES | Live streaming: 13,544 readings; latest probe received `<2m` ago (`2026-10-31 07:36:05 UTC`) | **PASS** |
| **WAN Quality Probe Stream** | YES | YES | YES | Live streaming: 43,510 quality probes; latest probe received `<1m` ago (`2026-10-31 07:38:09 UTC`) | **PASS** |
| **Hotspot Telemetry Stream** | YES | YES | YES | Live streaming: 74,304 user session records; latest record received `<2m` ago | **PASS** |
| **WAN Quota & Burn-Rate Engine**| YES | YES | YES | `view_mikrotik_wan_quota_status` active: WAN1 (28.6% used, 19d left, NORMAL), WAN2 (69.1% used, 7d left, NORMAL) | **PASS** |
| **WAN Quality Metrics** | YES | YES | YES | WAN1: 20ms latency, 0% loss (HEALTHY) | WAN2: 20ms latency, 0% loss (HEALTHY) | **PASS** |
| **Grafana Datasource** | YES | YES | YES | Datasource connects to PostgreSQL `campaign_db`, health status OK | **PASS** |
