#!/usr/bin/env node
const http = require('http');
const https = require('https');
const url = require('url');

function request(method, target, data) {
  return new Promise((resolve, reject) => {
    const u = url.parse(target);
    const lib = u.protocol === 'https:' ? https : http;
    const body = data ? JSON.stringify(data) : null;
    const opts = { method, hostname: u.hostname, port: u.port, path: u.path, headers: {} };
    if (body) {
      opts.headers['Content-Type'] = 'application/json';
      opts.headers['Content-Length'] = Buffer.byteLength(body);
    }
    const req = lib.request(opts, (res) => {
      let chunks = '';
      res.setEncoding('utf8');
      res.on('data', c => chunks += c);
      res.on('end', () => {
        try {
          const parsed = chunks ? JSON.parse(chunks) : null;
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function main() {
  const server = process.argv[2] || 'http://localhost:3000';
  const hostname = process.argv[3] || require('os').hostname();
  const public_key = process.argv[4] || null;

  const postUrl = server.replace(/\/$/, '') + '/api/agents/queue';
  console.log('Registering to queue at', postUrl);
  const resp = await request('POST', postUrl, { hostname, public_key });
  if (resp.status !== 201) {
    console.error('Failed to queue:', resp.status, resp.body);
    process.exit(1);
  }
  const qid = resp.body && resp.body.id;
  console.log('Queued with id', qid);

  const statusUrl = server.replace(/\/$/, '') + `/api/agents/queue/${qid}/status`;
  console.log('Polling status at', statusUrl);

  while (true) {
    const s = await request('GET', statusUrl);
    if (s.status !== 200) {
      console.error('Status check failed', s.status, s.body);
      process.exit(1);
    }
    const body = s.body || {};
    console.log(new Date().toISOString(), 'status=', body.status, body);
    if (body.status === 'approved') {
      console.log('Agent approved! agent_id=', body.agent_id);
      break;
    }
    if (body.status === 'rejected') {
      console.log('Agent rejected');
      break;
    }
    await new Promise(r => setTimeout(r, 3000));
  }
}

main().catch(err => { console.error(err); process.exit(2); });
