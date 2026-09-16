const http = require('node:http');
const https = require('node:https');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const PORT = Number(process.env.DSH_REMOTE_PORT || 3090);
const UPLOAD_DIR = path.join(os.homedir(), 'dsh-android-workspace');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

function send(res, code, data) {
  const body = JSON.stringify(data);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
  });
  res.end(body);
}

function listPlugins() {
  return new Promise((resolve) => {
    const url = 'https://registry.npmjs.org/-/v1/search?text=keywords:dsh-plugin&size=60';
    https.get(url, { headers: { 'User-Agent': 'dsh-android' } }, (r) => {
      let s = '';
      r.on('data', (d) => { s += d; });
      r.on('end', () => {
        try {
          const j = JSON.parse(s);
          const items = (j.objects || []).map((o) => ({
            name: o.package.name,
            version: o.package.version,
            description: o.package.description || '',
          }));
          resolve(items);
        } catch (e) {
          resolve([]);
        }
      });
    }).on('error', () => resolve([]));
  });
}

function installPlugin(pkg) {
  if (!/^[@a-z0-9._/-]+$/i.test(pkg)) {
    return { ok: false, output: 'invalid package name' };
  }
  const r = spawnSync('/Users/zp/bin/dsh', ['plugin', '--profile', 'web', 'add', pkg], {
    encoding: 'utf8',
    timeout: 120000,
  });
  return {
    ok: r.status === 0,
    output: ((r.stdout || '') + (r.stderr || '')).slice(-4000),
  };
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (d) => {
      size += d.length;
      if (size > 200 * 1024 * 1024) {
        reject(new Error('too large'));
        req.destroy();
        return;
      }
      chunks.push(d);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'OPTIONS') {
    send(res, 204, {});
    return;
  }
  if (req.method === 'GET' && url.pathname === '/health') {
    send(res, 200, { ok: true });
    return;
  }
  if (req.method === 'GET' && url.pathname === '/devices') {
    const nets = os.networkInterfaces();
    let lanIp = '';
    for (const name of Object.keys(nets)) {
      for (const ni of nets[name] || []) {
        if (ni.family === 'IPv4' && !ni.internal) {
          if (/^en[0-9]+$/.test(name)) {
            lanIp = ni.address;
          }
        }
      }
      if (lanIp) {
        break;
      }
    }
    send(res, 200, {
      devices: [{ id: 'mac', name: os.hostname(), host: lanIp, platform: 'darwin' }],
    });
    return;
  }
  if (req.method === 'GET' && url.pathname === '/plugins') {
    const plugins = await listPlugins();
    send(res, 200, { plugins });
    return;
  }
  if (req.method === 'POST' && url.pathname === '/install') {
    const body = await readBody(req);
    try {
      const pkg = JSON.parse(body.toString('utf8')).pkg;
      send(res, 200, installPlugin(String(pkg)));
    } catch (e) {
      send(res, 400, { ok: false, output: 'bad request' });
    }
    return;
  }
  if (req.method === 'POST' && url.pathname === '/upload') {
    try {
      const body = await readBody(req);
      const name = (url.searchParams.get('name') || 'file-' + Date.now()).replace(/[^a-zA-Z0-9._-]/g, '_');
      fs.writeFileSync(path.join(UPLOAD_DIR, name), body);
      send(res, 200, { ok: true, path: path.join(UPLOAD_DIR, name), bytes: body.length });
    } catch (e) {
      send(res, 500, { ok: false, output: String(e && e.message) });
    }
    return;
  }
  if (req.method === 'POST' && url.pathname === '/exec') {
    try {
      const body = await readBody(req);
      const cmd = String(JSON.parse(body.toString('utf8')).cmd || '').slice(0, 4000);
      if (!cmd) {
        send(res, 400, { ok: false, stdout: '', stderr: 'empty command' });
        return;
      }
      const r = spawnSync('/bin/bash', ['-lc', cmd], {
        encoding: 'utf8',
        timeout: 30000,
      });
      send(res, 200, {
        ok: r.status === 0,
        stdout: (r.stdout || '').slice(-8000),
        stderr: (r.stderr || '').slice(-8000),
      });
    } catch (e) {
      send(res, 400, { ok: false, stdout: '', stderr: String(e && e.message) });
    }
    return;
  }
  send(res, 404, { ok: false, output: 'not found' });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`remote-api listening 127.0.0.1:${PORT}`);
});
