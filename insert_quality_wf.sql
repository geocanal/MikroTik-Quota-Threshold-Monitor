
INSERT INTO workflow_entity (
    id, name, active, nodes, connections, settings, "createdAt", "updatedAt", "versionId", "triggerCount"
)
VALUES (
    'mikrotik-wan-quality-monitor',
    'MikroTik - WAN Quality Monitor',
    true,
    '[{"parameters": {"httpMethod": "POST", "path": "mikrotik/wan-quality", "options": {}}, "type": "n8n-nodes-base.webhook", "typeVersion": 2, "position": [900, 400], "id": "wh-wan-quality-001", "name": "WAN Quality Webhook", "webhookId": "b1a2c3d4-wan-quality-webhook"}, {"parameters": {"jsCode": "const body = $json.body || $json;\n\nif (!body) {\n  throw new Error(''Missing request body'');\n}\n\nconst routerId = body.router_id || ''RB5009-Core'';\nconst probes = Array.isArray(body.probes) ? body.probes : [];\nconst receivedAt = new Date().toISOString();\n\nif (probes.length === 0) {\n  return [];\n}\n\nreturn probes.map(p => {\n  const latency = Number(p.latency_ms || 0);\n  const minLat = p.min_latency_ms !== undefined ? Number(p.min_latency_ms) : latency;\n  const maxLat = p.max_latency_ms !== undefined ? Number(p.max_latency_ms) : latency;\n  const loss = Number(p.packet_loss_percent || 0);\n  const jitter = Number(Math.max(0, maxLat - minLat).toFixed(2));\n  \n  let status = p.status || ''HEALTHY'';\n  if (loss >= 100) {\n    status = ''DOWN'';\n  } else if (loss >= 30 || latency >= 180) {\n    status = ''DEGRADED'';\n  } else {\n    status = ''HEALTHY'';\n  }\n\n  return {\n    json: {\n      router_id: routerId,\n      interface_name: p.interface,\n      target_host: p.target || ''8.8.8.8'',\n      latency_ms: latency,\n      min_latency_ms: minLat,\n      max_latency_ms: maxLat,\n      packet_loss_percent: loss,\n      jitter_ms: jitter,\n      status: status,\n      probed_at: receivedAt\n    }\n  };\n});"}, "type": "n8n-nodes-base.code", "typeVersion": 2, "position": [1120, 400], "id": "code-process-quality-002", "name": "Normalize Quality Probes"}, {"parameters": {"operation": "executeQuery", "query": "INSERT INTO mikrotik_wan_quality (\n    router_id,\n    interface_name,\n    target_host,\n    latency_ms,\n    min_latency_ms,\n    max_latency_ms,\n    packet_loss_percent,\n    jitter_ms,\n    status,\n    probed_at\n)\nVALUES (\n    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10\n);", "options": {"queryReplacement": "={{ [\n  $json.router_id,\n  $json.interface_name,\n  $json.target_host,\n  $json.latency_ms,\n  $json.min_latency_ms,\n  $json.max_latency_ms,\n  $json.packet_loss_percent,\n  $json.jitter_ms,\n  $json.status,\n  $json.probed_at\n] }}"}}, "type": "n8n-nodes-base.postgres", "typeVersion": 2.7, "position": [1340, 400], "id": "pg-store-quality-003", "name": "Store Quality Probes", "credentials": {"postgres": {"id": "XKwdrIadj1gSLirP", "name": "Postgres account"}}}]'::json,
    '{"WAN Quality Webhook": {"main": [[{"node": "Normalize Quality Probes", "type": "main", "index": 0}]]}, "Normalize Quality Probes": {"main": [[{"node": "Store Quality Probes", "type": "main", "index": 0}]]}}'::json,
    '{"executionOrder": "v1"}'::json,
    NOW(),
    NOW(),
    'a7504943-62eb-46a1-8f10-84046da0482c',
    1
)
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    active = EXCLUDED.active,
    nodes = EXCLUDED.nodes,
    connections = EXCLUDED.connections,
    settings = EXCLUDED.settings,
    "updatedAt" = NOW(),
    "versionId" = EXCLUDED."versionId",
    "triggerCount" = EXCLUDED."triggerCount";
