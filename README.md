# MikroTik Quota Threshold Monitor & Policy Control Plane

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![RouterOS](https://img.shields.io/badge/RouterOS-v7.x-blue.svg)](https://mikrotik.com)
[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15%2B-blue.svg)](https://www.postgresql.org/)
[![Grafana](https://img.shields.io/badge/Grafana-v11%2B-orange.svg)](https://grafana.com/)
[![n8n](https://img.shields.io/badge/Orchestration-n8n-red.svg)](https://n8n.io/)

A distributed, enterprise-grade network automation, quota burn-rate monitoring, and policy-based routing (PBR) control plane designed for **MikroTik RouterOS v7** multi-WAN deployments.

---

## 📌 Problem & Overview

Managing multi-WAN connections with metered monthly quotas (e.g., DSL/Fiber packages with FUP caps) presents recurring challenges:
- **Overage charges & throttling**: When a metered WAN exhausts its allowance, traffic silently degrades or incurs high cost.
- **Lack of ISP SLA dispute records**: When an ISP suffers recurring micro-outages or high latency, subscribers lack verifiable timestamped logs to claim compensation.
- **Hotspot abuse & visibility gaps**: Unmonitored bandwidth consumption by individual hotspot clients drains package quotas prematurely.

This repository provides an automated, zero-touch operational ecosystem:
1. **Periodic Telemetry Collection**: RouterOS scripts collect interface byte counters, ICMP latency/loss probes, and active hotspot client data.
2. **Orchestrated Ingestion & Evaluation**: **n8n** webhook workflows ingest telemetry, compute delta consumption, and trigger policy thresholds.
3. **Relational Quota Ledger**: **PostgreSQL** stores time-series readings, monthly billing cycle quotas, ISP outage events, and hotspot usage.
4. **Interactive Operations Bot**: A multi-threaded **Telegram Ops Bot** delivers proactive quota threshold alerts (80%, 95%, 100%), smart failover diagnostics, and interactive control buttons.
5. **Automated Policy Routing (PBR)**: Dynamically isolates exhausted WANs into fallback blackhole/bypass tables and automatically restores them upon quota renewal.
6. **Zero-Touch Observability**: Pre-provisioned **Grafana** dashboards providing real-time WAN burn rate, hotspot client consumption, and SLA health.

---

## 🏗️ Architecture

```
                                  +----------------------------+
                                  |    MikroTik RouterOS v7    |
                                  |  - wan_control_pbr.rsc     |
                                  |  - wan_quality.rsc         |
                                  |  - hotspot_telemetry.rsc   |
                                  +--------------+-------------+
                                                 |
                               HTTP Webhooks     |   Scheduled Fetch
                                                 v
                                  +----------------------------+
                                  |       n8n Workflows        |
                                  |  - Quota Ingestion & Calc  |
                                  |  - Latency & Loss Monitor  |
                                  |  - Hotspot Session Track   |
                                  +--------------+-------------+
                                                 |
                                      SQL INSERT / EVALUATE
                                                 v
                                  +----------------------------+
                                  |    PostgreSQL Database     |
                                  |  - schema.sql              |
                                  |  - Quota Status Views      |
                                  |  - ISP Outage Event Log    |
                                  +-------+--------------+-----+
                                          |              |
                    Real-time Queries     |              | Telemetry & Polling
                                          v              v
               +----------------------------+   +----------------------------+
               |     Grafana Dashboards     |   |    Telegram Ops Bot        |
               |  - mikrotik-overview.json  |   |  - telegram_bot_daemon.py  |
               |  - hotspot-overview.json   |   |  - Live Alerts & Overrides |
               +----------------------------+   +----------------------------+
```

---

## ✨ Key Features

- **Dual-WAN Multi-Homing Quota Engine**:
  - Independent monthly billing cycle tracking for multiple ISPs (e.g., Vodafone DSL + WE Egypt VDSL).
  - Configurable quota allowances, daily burn-rate projection, and threshold notifications at 80%, 95%, and 100%.
- **Policy-Based Routing (PBR) Isolation**:
  - RouterOS routing table separation (`to_WAN1`, `to_WAN2`).
  - Automatic isolation of exhausted links to prevent overage costs, with seamless failover to healthy links.
- **ISP Outage & SLA Dispute Logging**:
  - Continuous ICMP quality probes measuring latency and packet loss.
  - Automatic logging of ISP downtime events in `wan_outage_events` to back billing dispute claims with precise duration evidence.
- **Hotspot Telemetry & Voucher Analytics**:
  - Real-time client session tracking: active MAC addresses, assigned IP, session uptime, bytes in/out.
  - Identification of bandwidth hogs and voucher expiration states.
- **Interactive Telegram Operations Bot**:
  - Interactive on-screen keyboard: `/status`, `/failover`, `/hotspot`, `/claim`.
  - Instant SLA claim summary generation formatted for ISP customer support escalation.
- **Chunked Data Retention Engine (`prune_telemetry.py`)**:
  - Automated non-locking deletion of high-frequency telemetry (ICMP ping records >14 days, hotspot records >30 days) to prevent disk bloat.
- **Zero-Touch Provisioning**:
  - Standalone Docker Compose configuration (`docker-compose.monitoring.yml`) mounting provisioned PostgreSQL data sources and Grafana dashboards.

---

## 📂 Repository Structure

```
.
├── .agents/                               # LLM & Agentic navigation layer
│   ├── context/                           # System architecture, codebase maps, data flows
│   └── scripts/                           # Navigation and drift validation tools
├── provisioning/                          # Grafana automated provisioning
│   ├── dashboards/                        # Dashboard JSON models (WAN & Hotspot)
│   └── datasources/                       # PostgreSQL datasource definition
├── schema.sql                             # PostgreSQL DDL, views, and seed data
├── docker-compose.monitoring.yml          # Grafana monitoring container stack
├── wan_control_pbr.rsc                    # RouterOS: Dual-WAN PBR and isolation logic
├── wan_quality.rsc                        # RouterOS: ICMP latency & loss probe script
├── hotspot_telemetry.rsc                  # RouterOS: Hotspot user session telemetry
├── wccp_control.rsc                       # RouterOS: WCCP cache redirection helper
├── MikroTik - Quota Threshold Monitor.json# n8n: Quota tracking & threshold alert workflow
├── MikroTik - WAN Quality Ingestion.json  # n8n: Latency & loss metrics ingestion
├── MikroTik - Hotspot Ingestion.json      # n8n: Hotspot active session ingestion
├── MikroTik - Telegram Interactive Bot.json # n8n: Telegram callback handler workflow
├── MikroTik - Router Offline Monitor.json # n8n: Router heartbeat and offline alert
├── telegram_bot_daemon.py                 # Multi-threaded Telegram control daemon (Local)
├── telegram_bot_daemon_oci.py             # Production-optimized Telegram bot daemon
├── prune_telemetry.py                     # Non-locking telemetry retention & cleanup script
├── test_prune_telemetry.py                # Automated unit tests for retention engine
├── .env.example                           # Sample environment configuration template
├── DEPLOYMENT.md                          # 5-phase production deployment guide
├── SERVICE_HEALTH_MATRIX.md               # Health verification checklist & metric standards
└── LICENSE                                # MIT License
```

---

## 🚀 Quickstart Guide

### 1. Database Initialization
Deploy PostgreSQL (version 15+ recommended) and initialize the schema:
```bash
# Set up database and tables
psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME> -f schema.sql
```

### 2. Configure Environment Variables
Copy `.env.example` to `.env` and fill in your credentials:
```bash
cp .env.example .env
```
Key variables:
- `TELEGRAM_BOT_TOKEN`: Token obtained from [@BotFather](https://t.me/BotFather).
- `TELEGRAM_ADMIN_CHAT_ID`: Your numerical Telegram user/chat ID.
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`: PostgreSQL connection settings.

### 3. Deploy RouterOS Scripts
1. Open RouterOS WinBox or SSH terminal.
2. Review and import scripts:
   - `wan_quality.rsc`: Schedule every 1-2 minutes to push latency probes to n8n webhook.
   - `hotspot_telemetry.rsc`: Schedule every 5-15 minutes to record active client usage.
   - `wan_control_pbr.rsc`: Configures routing tables and isolation marks.

### 4. Import n8n Workflows
1. In your n8n instance, navigate to **Workflows -> Import from File**.
2. Import the JSON workflows:
   - `MikroTik - Quota Threshold Monitor.json`
   - `MikroTik - WAN Quality Ingestion.json`
   - `MikroTik - Hotspot Ingestion.json`
3. Configure PostgreSQL credentials in n8n and activate workflows.

### 5. Launch Grafana Monitoring
Start the Grafana visualization container:
```bash
docker compose -f docker-compose.monitoring.yml up -d
```
Access Grafana at `http://localhost:3000` (default credentials: `admin` / `admin`). Pre-configured dashboards will load automatically.

### 6. Run the Telegram Bot Daemon
Install Python dependencies and start the daemon:
```bash
pip install requests psycopg2-binary
python telegram_bot_daemon.py
```
For production Linux servers, a systemd unit file can be configured to manage the bot daemon persistently.

### 7. Telemetry Retention Engine
Schedule periodic cleanup of historical high-frequency logs:
```bash
# Add to crontab (runs daily at 03:00)
0 3 * * * /usr/bin/python3 /path/to/prune_telemetry.py >> /var/log/prune_telemetry.log 2>&1
```

---

## 🛡️ Security & Privacy

- **Decoupled Secrets**: All passwords, API tokens, and chat IDs are strictly loaded from environment variables or local `.env` files (ignored in `.gitignore`).
- **Anonymized Configurations**: Example scripts and documentation use RFC-5737 documentation IP ranges (`198.51.100.x`) and generic placeholder domains (`example.com`).
- **Sanitized Git History**: Clean commit history vetted against exposed credentials.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!
1. Fork the Project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your Changes (`git commit -m 'feat: add some amazing feature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more details.
