import json

with open('d:/Work/MikroTik - Quota Threshold Monitor/wan_dashboard_backup.json', 'r', encoding='utf-16') as f:
    d = json.load(f)

dash = d['dashboard']

# Re-position existing panels to create space
# Original:
# id 1: gauge (h:8, w:12, x:0, y:0)
# id 2: piechart (h:8, w:12, x:12, y:0)
# id 3: timeseries throughput (h:8, w:24, x:0, y:8)
# id 4: barchart daily (h:8, w:14, x:0, y:16)
# id 5: table summary (h:8, w:10, x:14, y:16)

# We will add:
# Row 0: Row header "ISP Quotas & Traffic Overview" (or keep id 1, 2 at y=0)
# id 1: (h:7, w:12, x:0, y:0)
# id 2: (h:7, w:12, x:12, y:0)
# id 3: Throughput (h:7, w:24, x:0, y:7)
# id 4: Daily barchart (h:7, w:14, x:0, y:14)
# id 5: Quota table (h:7, w:10, x:14, y:14)

# New Section at y=21:
# id 6: Row "WAN Quality & SLA Monitoring (Latency / Packet Loss / Uptime)"
# id 7: Timeseries "WAN Latency (ms) - Ping to 8.8.8.8" (h:8, w:12, x:0, y:22)
# id 8: Timeseries "Packet Loss (%) & Health Status" (h:8, w:12, x:12, y:22)
# id 9: Gauge / Stat "Monthly ISP SLA Availability (%)" (h:6, w:8, x:0, y:30)
# id 10: Stat "Total ISP Outage Downtime" (h:6, w:6, x:8, y:30)
# id 11: Table "ISP Outage Audit & Compensation Log" (h:6, w:10, x:14, y:30)

# New Section at y=36:
# id 12: Row "Hotspot Top Talkers & Live Consumers"
# id 13: Table "Top Hotspot Bandwidth Consumers (Cumulative)" (h:9, w:14, x:0, y:37)
# id 14: Piechart "Hotspot Traffic Share by Profile" (h:9, w:10, x:14, y:37)

existing_panels = dash['panels']
for p in existing_panels:
    if p['id'] == 1:
        p['gridPos'] = {'h': 7, 'w': 12, 'x': 0, 'y': 0}
    elif p['id'] == 2:
        p['gridPos'] = {'h': 7, 'w': 12, 'x': 12, 'y': 0}
    elif p['id'] == 3:
        p['gridPos'] = {'h': 7, 'w': 24, 'x': 0, 'y': 7}
    elif p['id'] == 4:
        p['gridPos'] = {'h': 7, 'w': 14, 'x': 0, 'y': 14}
    elif p['id'] == 5:
        p['gridPos'] = {'h': 7, 'w': 10, 'x': 14, 'y': 14}

datasource = {'type': 'postgres', 'uid': 'PCC52D03280B7034C'}

panel_quality_row = {
    "collapsed": False,
    "gridPos": {"h": 1, "w": 24, "x": 0, "y": 21},
    "id": 6,
    "panels": [],
    "title": "⚡ Live WAN Quality & ISP SLA Telemetry",
    "type": "row"
}

panel_latency_ts = {
    "id": 7,
    "title": "WAN Latency (RTT ms) - 24 Hours",
    "type": "timeseries",
    "datasource": datasource,
    "gridPos": {"h": 8, "w": 12, "x": 0, "y": 22},
    "fieldConfig": {
        "defaults": {
            "custom": {
                "drawStyle": "line",
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "fillOpacity": 15
            },
            "unit": "ms",
            "thresholds": {
                "mode": "absolute",
                "steps": [
                    {"color": "green", "value": None},
                    {"color": "#EAB839", "value": 50},
                    {"color": "red", "value": 150}
                ]
            }
        },
        "overrides": []
    },
    "options": {
        "legend": {"calcs": ["mean", "max", "lastNotNull"], "displayMode": "table", "placement": "bottom"},
        "tooltip": {"mode": "multi"}
    },
    "targets": [
        {
            "format": "time_series",
            "rawQuery": True,
            "rawSql": "SELECT probed_at AS time, CASE WHEN UPPER(interface_name) = 'WAN1' THEN 'Vodafone (WAN1) RTT' ELSE 'WE (WAN2) RTT' END AS metric, latency_ms FROM mikrotik_wan_quality WHERE $__timeFilter(probed_at) ORDER BY probed_at ASC;",
            "refId": "A"
        }
    ]
}

panel_loss_ts = {
    "id": 8,
    "title": "Packet Loss (%) & Connection Degradation",
    "type": "timeseries",
    "datasource": datasource,
    "gridPos": {"h": 8, "w": 12, "x": 12, "y": 22},
    "fieldConfig": {
        "defaults": {
            "custom": {
                "drawStyle": "line",
                "lineInterpolation": "linear",
                "lineWidth": 2,
                "fillOpacity": 25
            },
            "unit": "percent",
            "min": 0,
            "max": 100,
            "thresholds": {
                "mode": "absolute",
                "steps": [
                    {"color": "green", "value": None},
                    {"color": "#EAB839", "value": 5},
                    {"color": "red", "value": 25}
                ]
            }
        },
        "overrides": []
    },
    "options": {
        "legend": {"calcs": ["max", "lastNotNull"], "displayMode": "table", "placement": "bottom"},
        "tooltip": {"mode": "multi"}
    },
    "targets": [
        {
            "format": "time_series",
            "rawQuery": True,
            "rawSql": "SELECT probed_at AS time, CASE WHEN UPPER(interface_name) = 'WAN1' THEN 'Vodafone (WAN1) Loss %' ELSE 'WE (WAN2) Loss %' END AS metric, packet_loss_percent FROM mikrotik_wan_quality WHERE $__timeFilter(probed_at) ORDER BY probed_at ASC;",
            "refId": "A"
        }
    ]
}

panel_sla_gauge = {
    "id": 9,
    "title": "Monthly SLA Uptime (%)",
    "type": "gauge",
    "datasource": datasource,
    "gridPos": {"h": 6, "w": 6, "x": 0, "y": 30},
    "fieldConfig": {
        "defaults": {
            "min": 95,
            "max": 100,
            "unit": "percent",
            "thresholds": {
                "mode": "absolute",
                "steps": [
                    {"color": "red", "value": None},
                    {"color": "#EAB839", "value": 98},
                    {"color": "green", "value": 99.5}
                ]
            }
        },
        "overrides": []
    },
    "options": {
        "reduceOptions": {"calcs": ["lastNotNull"], "values": False},
        "showThresholdLabels": True,
        "showThresholdMarkers": True
    },
    "targets": [
        {
            "format": "table",
            "rawQuery": True,
            "rawSql": "SELECT ROUND((100.0 - (COALESCE(SUM(duration_minutes), 0) / (EXTRACT(DAY FROM DATE_TRUNC('month', NOW()) + INTERVAL '1 month - 1 day') * 24.0 * 60.0) * 100.0))::numeric, 2) AS uptime_pct FROM wan_outage_events WHERE started_at >= DATE_TRUNC('month', NOW());",
            "refId": "A"
        }
    ]
}

panel_sla_stat = {
    "id": 10,
    "title": "Documented Downtime (Current Month)",
    "type": "stat",
    "datasource": datasource,
    "gridPos": {"h": 6, "w": 6, "x": 6, "y": 30},
    "fieldConfig": {
        "defaults": {
            "unit": "m",
            "thresholds": {
                "mode": "absolute",
                "steps": [
                    {"color": "green", "value": None},
                    {"color": "#EAB839", "value": 30},
                    {"color": "red", "value": 60}
                ]
            }
        },
        "overrides": []
    },
    "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "auto",
        "reduceOptions": {"calcs": ["lastNotNull"], "values": False}
    },
    "targets": [
        {
            "format": "table",
            "rawQuery": True,
            "rawSql": "SELECT COALESCE(SUM(duration_minutes), 0) AS downtime_minutes FROM wan_outage_events WHERE started_at >= DATE_TRUNC('month', NOW());",
            "refId": "A"
        }
    ]
}

panel_outage_table = {
    "id": 11,
    "title": "ISP Outage Audit & Legal Compensation Claims",
    "type": "table",
    "datasource": datasource,
    "gridPos": {"h": 6, "w": 12, "x": 12, "y": 30},
    "fieldConfig": {
        "defaults": {
            "custom": {"align": "auto"}
        },
        "overrides": []
    },
    "options": {
        "sortBy": [{"displayName": "Start Time", "desc": True}]
    },
    "targets": [
        {
            "format": "table",
            "rawQuery": True,
            "rawSql": "SELECT UPPER(interface_name) AS \"Line\", provider_name AS \"ISP\", started_at AS \"Start Time\", duration_minutes || ' min' AS \"Duration\", outage_cause AS \"Cause\", CASE WHEN email_sent THEN '✅ Dispatched (' || email_recipient || ')' ELSE '❌ Pending' END AS \"Claim Status\" FROM wan_outage_events ORDER BY started_at DESC LIMIT 5;",
            "refId": "A"
        }
    ]
}

panel_hotspot_row = {
    "collapsed": False,
    "gridPos": {"h": 1, "w": 24, "x": 0, "y": 36},
    "id": 12,
    "panels": [],
    "title": "👥 Hotspot Network & Top Talkers",
    "type": "row"
}

panel_hotspot_top = {
    "id": 13,
    "title": "Top Bandwidth Consumers (Cumulative)",
    "type": "table",
    "datasource": datasource,
    "gridPos": {"h": 8, "w": 15, "x": 0, "y": 37},
    "fieldConfig": {
        "defaults": {
            "custom": {"align": "auto"}
        },
        "overrides": []
    },
    "options": {
        "sortBy": [{"displayName": "Total (GB)", "desc": True}]
    },
    "targets": [
        {
            "format": "table",
            "rawQuery": True,
            "rawSql": "SELECT user_name AS \"User\", COALESCE(profile, '-') AS \"Profile\", ip_address AS \"IP\", ROUND(total_gb, 2) AS \"Total (GB)\", used_percentage || '%' AS \"Quota %\", CASE WHEN is_active THEN '🟢 Active Online' ELSE '⚪ Offline' END AS \"Session\", session_uptime AS \"Uptime\" FROM (SELECT DISTINCT ON (user_name) * FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) latest ORDER BY total_bytes DESC LIMIT 10;",
            "refId": "A"
        }
    ]
}

panel_hotspot_pie = {
    "id": 14,
    "title": "Hotspot Consumption Share by Profile",
    "type": "piechart",
    "datasource": datasource,
    "gridPos": {"h": 8, "w": 9, "x": 15, "y": 37},
    "fieldConfig": {
        "defaults": {
            "unit": "decgbytes"
        },
        "overrides": []
    },
    "options": {
        "legend": {"displayMode": "table", "placement": "right", "values": ["value", "percent"]},
        "pieType": "pie",
        "reduceOptions": {"calcs": ["lastNotNull"], "values": False},
        "tooltip": {"mode": "single"}
    },
    "targets": [
        {
            "format": "table",
            "rawQuery": True,
            "rawSql": "SELECT COALESCE(profile, 'Default') AS metric, ROUND(SUM(total_gb), 2) AS value FROM (SELECT DISTINCT ON (user_name) * FROM hotspot_user_telemetry ORDER BY user_name, recorded_at DESC) latest GROUP BY 1 ORDER BY value DESC;",
            "refId": "A"
        }
    ]
}

new_panels = [
    *existing_panels,
    panel_quality_row,
    panel_latency_ts,
    panel_loss_ts,
    panel_sla_gauge,
    panel_sla_stat,
    panel_outage_table,
    panel_hotspot_row,
    panel_hotspot_top,
    panel_hotspot_pie
]

dash['panels'] = new_panels

out_payload = {
    "dashboard": dash,
    "overwrite": True
}

with open('d:/Work/MikroTik - Quota Threshold Monitor/updated_wan_dashboard.json', 'w', encoding='utf-8') as f:
    json.dump(out_payload, f, indent=2, ensure_ascii=False)

print("SUCCESS: Generated updated_wan_dashboard.json with all requested advanced panels!")
