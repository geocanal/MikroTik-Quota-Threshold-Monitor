import requests

payload = {
    "router_id": "home-router-01",
    "probes": [
        {
            "interface": "wan1",
            "target": "8.8.8.8",
            "latency_ms": 14.5,
            "min_latency_ms": 12.1,
            "max_latency_ms": 16.8,
            "packet_loss_percent": 0.0,
            "status": "HEALTHY"
        },
        {
            "interface": "wan2",
            "target": "8.8.8.8",
            "latency_ms": 22.3,
            "min_latency_ms": 19.5,
            "max_latency_ms": 28.1,
            "packet_loss_percent": 0.0,
            "status": "HEALTHY"
        }
    ]
}

r = requests.post('http://127.0.0.1:5678/webhook/mikrotik/wan-quality', json=payload)
print('STATUS:', r.status_code)
print('BODY:', r.text)
