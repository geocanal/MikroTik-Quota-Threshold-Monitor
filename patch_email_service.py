import sys
import os

with open('/app/app.py', 'r') as f:
    content = f.read()

email_snippet = '''

# --- Email Dispatcher Microservice ---
from pydantic import BaseModel
from typing import Optional
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

class EmailPayload(BaseModel):
    to_email: str
    cc_email: Optional[str] = None
    subject: str
    html_content: str
    plain_content: Optional[str] = None

@app.post("/send-email")
def send_email_endpoint(payload: EmailPayload):
    user = os.getenv("SMTP_USER", "admin@example.com")
    password = os.getenv("SMTP_PASSWORD", "YOUR_SMTP_APP_PASSWORD")
    host = os.getenv("SMTP_HOST", "smtp.gmail.com")
    port = int(os.getenv("SMTP_PORT", "587"))

    msg = MIMEMultipart("alternative")
    sender_display = "اسم المشترك"
    msg["From"] = f"{sender_display} <{user}>"
    msg["To"] = payload.to_email
    if payload.cc_email:
        msg["Cc"] = payload.cc_email
    msg["Subject"] = payload.subject

    if payload.plain_content:
        msg.attach(MIMEText(payload.plain_content, "plain", "utf-8"))
    msg.attach(MIMEText(payload.html_content, "html", "utf-8"))

    recipients = [payload.to_email]
    if payload.cc_email:
        recipients.append(payload.cc_email)

    try:
        server = smtplib.SMTP(host, port, timeout=15)
        server.starttls()
        server.login(user, password)
        server.sendmail(user, recipients, msg.as_string())
        server.quit()
        return {"status": "success", "message": "Email sent successfully", "recipients": recipients}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
'''

if '/send-email' not in content:
    with open('/app/app.py', 'a') as f:
        f.write(email_snippet)
    print("ENDPOINT_ADDED")
else:
    print("ENDPOINT_ALREADY_EXISTS")
