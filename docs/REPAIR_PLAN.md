# System Repair & Maintenance Plan

**Priority Classification:**
- **P0 (Critical):** Immediate blocker, data loss, or system outage.
- **P1 (High):** Telemetry freshness, core monitoring automation.
- **P2 (Medium):** Observability enhancements, UX, and non-blocking warnings.
- **P3 (Low):** Documentation and cleanup.

---

### Priority Item 1: Resume MikroTik Router Telemetry Push (P1 - High)
- **Target:** MikroTik Router (Terminal / WinBox)
- **Description:**
  Server-side webhooks (`https://n8n.example.com/webhook/mikrotik/wan-usage` and `mikrotik/wan-quality`) are fully healthy and responsive. The router needs its DNS cache refreshed and its scheduled scripts verified to re-establish the continuous flow of packets.
- **Repair Steps:**
  1. In RouterOS Terminal, flush DNS cache:
     ```routeros
     /ip dns cache flush
     ```
  2. Run a one-time test push:
     ```routeros
     /system script run send-wan-telemetry
     /system script run send-wan-quality
     ```
  3. Ensure schedulers are enabled and not suspended:
     ```routeros
     /system scheduler print
     /system scheduler enable [find name="schedule-wan-telemetry"]
     /system scheduler enable [find name="schedule-wan-quality"]
     ```
- **Acceptance Criteria:**
  Running `SELECT MAX(probed_at) FROM mikrotik_wan_quality;` on `campaign_db` returns a timestamp within the last 5 minutes.
- **Rollback:** No rollback needed; scripts are read-only probes.

---

### Priority Item 2: Grafana Container Dual-Network Persistence (Completed & Verified) (P2 - Medium)
- **Target:** `deploy-server` (`/home/deploy/mikrotik-monitoring/docker-compose.yml`)
- **Status:** **REPAIRED & VERIFIED**
- **Action Taken:**
  Updated Grafana docker-compose file to attach `app_default` and `n8n_n8n` networks permanently, and pointed datasource to `app-postgres-1:5432`. Health check confirmed `{"message": "Database Connection OK", "status": "OK"}`.

---

### Priority Item 3: Telegram Bot Webhook Polling Isolation (Completed & Verified) (P2 - Medium)
- **Target:** `deploy-server` (`mikrotik-telegram-bot.service` + n8n `webhook_entity`)
- **Status:** **REPAIRED & VERIFIED**
- **Action Taken:**
  Cleared conflicting webhook from n8n database to prevent HTTP 409 conflict. Verified Telegram Bot Daemon runs cleanly with zero conflict errors.
