import json

with open("MikroTik - Telegram Interactive Bot.json", "r", encoding="utf-8") as f:
    wf = json.load(f)

nodes = wf["nodes"]
connections = wf["connections"]

# 1. Replace "Telegram Trigger" node with "Webhook" node
new_nodes = []
for n in nodes:
    if n["name"] == "Telegram Trigger":
        new_nodes.append({
            "parameters": {
                "httpMethod": "POST",
                "path": "mikrotik/telegram-bot",
                "options": {}
            },
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 2,
            "position": [200, 300],
            "id": "wh-telegram-bot-trigger",
            "name": "Webhook"
        })
    elif n["name"] == "Auth & Dispatcher":
        n["parameters"]["jsCode"] = """const raw = $input.first()?.json?.body || $input.first()?.json || {};
const allowedAdmin = $env.TELEGRAM_ADMIN_CHAT_ID || '123456789';

// Handle Callback Query (Button Clicks)
if (raw.callback_query) {
  const cq = raw.callback_query;
  const fromId = String(cq.from?.id);
  const data = cq.data || '';
  
  return [{
    json: {
      type: 'callback',
      is_authorized: fromId === String(allowedAdmin),
      chat_id: cq.message?.chat?.id || allowedAdmin,
      from_id: fromId,
      callback_query_id: cq.id,
      data: data,
      user_name: cq.from?.username || cq.from?.first_name || 'Admin'
    }
  }];
}

// Handle Direct Messages / Slash Commands
if (raw.message) {
  const msg = raw.message;
  const fromId = String(msg.from?.id);
  const text = (msg.text || '').trim();
  
  return [{
    json: {
      type: 'message',
      is_authorized: fromId === String(allowedAdmin),
      chat_id: msg.chat?.id || allowedAdmin,
      from_id: fromId,
      text: text,
      user_name: msg.from?.username || msg.from?.first_name || 'Admin'
    }
  }];
}

return [];"""
        new_nodes.append(n)
    else:
        new_nodes.append(n)

wf["nodes"] = new_nodes

# Update connections: change "Telegram Trigger" to "Webhook"
if "Telegram Trigger" in connections:
    connections["Webhook"] = connections.pop("Telegram Trigger")

with open("MikroTik - Telegram Interactive Bot.json", "w", encoding="utf-8") as f:
    json.dump(wf, f, ensure_ascii=False, indent=2)

print("CONVERTED_SUCCESSFULLY")
