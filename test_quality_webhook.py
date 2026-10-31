import subprocess

script = """
cat << 'EOF' > /tmp/test_quality_payload.py
import requests

payload = {
    "router_id": "RB5009-Core",
    "probes": [
        {
            "interface": "wan1",
            "target": "8.8.8.8",
            "latency_ms": 18.5,
            "min_latency_ms": 16.0,
            "max_latency_ms": 22.0,
            "packet_loss_percent": 0.0,
            "status": "HEALTHY"
        },
        {
            "interface": "wan2",
            "target": "8.8.8.8",
            "latency_ms": 24.2,
            "min_latency_ms": 21.0,
            "max_latency_ms": 29.5,
            "packet_loss_percent": 0.0,
            "status": "HEALTHY"
        }
    ]
}

r = requests.post("http://n8n:5678/webhook/mikrotik/wan-quality", json=payload, timeout=10)
print("STATUS_CODE:", r.status_code)
print("RESPONSE:", r.text)
EOF

sudo docker run --rm --network n8n_n8n -v /tmp/test_quality_payload.py:/tmp/test_quality_payload.py python:3.11-alpine sh -c "pip install requests -q && python /tmp/test_quality_payload.py"
"""

cmd = [
    'ssh', '-F', r'C:\Users\Ahmed Mohamed\.ssh\config',
    'deploy-server',
    script
]
print(subprocess.check_output(cmd, text=True))
