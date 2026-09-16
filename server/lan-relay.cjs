const net = require('node:net');

const LISTEN_PORT = Number(process.env.DSH_RELAY_PORT || 3082);
const TARGET_HOST = '127.0.0.1';
const TARGET_PORT = Number(process.env.DSH_RELAY_TARGET || 3081);

const server = net.createServer((client) => {
  const upstream = net.connect(TARGET_PORT, TARGET_HOST, () => {
    client.pipe(upstream);
    upstream.pipe(client);
  });
  upstream.on('error', () => client.destroy());
  client.on('error', () => upstream.destroy());
});

server.listen(LISTEN_PORT, '0.0.0.0', () => {
  console.log(`relay listening 0.0.0.0:${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT}`);
});
