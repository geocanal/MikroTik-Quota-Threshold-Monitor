const http = require('http');

const data = JSON.stringify({
    to_email: 'admin@example.com',
    subject: 'تجربة إرسال الإيميل من n8n مباشرة',
    html_content: '<h2>تم بنجاح!</h2><p>هذا إيميل تجريبي للتأكد من نجاح الإرسال التلقائي عبر منظومة n8n.</p>'
});

const req = http.request({
    hostname: 'n8n-text-overlay',
    port: 8000,
    path: '/send-email',
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
    }
}, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => console.log('STATUS:', res.statusCode, 'BODY:', body));
});

req.on('error', (e) => console.error('ERROR:', e));
req.write(data);
req.end();
