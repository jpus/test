const express = require("express");
const app = express();
const net = require('net');
const { WebSocket, createWebSocketStream } = require('ws');
const uuid = (process.env.UUID || 'ffffffff-ffff-ffff-ffff-ffffffffffff').replace(/-/g, '');

app.get("/", (req, res) => {
  res.send("hello world");
});

const server = app.listen(process.env.PORT || 0, () => {
  console.log(`Server is listening`);
});

const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
  ws.once('message', (msg) => {
    const [VERSION] = msg;
    const id = msg.slice(1, 17);

    if (!id.every((v, i) => v == parseInt(uuid.substr(i * 2, 2), 16))) {
      return;
    }

    let i = msg.slice(17, 18).readUInt8() + 19;
    const port = msg.slice(i, (i += 2)).readUInt16BE(0);
    const ATYP = msg.slice(i, (i += 1)).readUInt8();

    const host =
      ATYP == 1
        ? msg.slice(i, (i += 4)).join('.')
        : ATYP == 2
        ? new TextDecoder().decode(msg.slice(i + 1, (i += 1 + msg.slice(i, i + 1).readUInt8())))
        : ATYP == 3
        ? msg.slice(i, (i += 16)).reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), [])
            .map((b) => b.readUInt16BE(0).toString(16))
            .join(':')
        : '';

    ws.send(new Uint8Array([VERSION, 0]));

    const duplex = createWebSocketStream(ws);

    net.connect({ host, port }, function () {
      this.write(msg.slice(i));
      duplex
        .on('error', () => {})
        .pipe(this)
        .on('error', () => {})
        .pipe(duplex);
    }).on('error', () => {});
  }).on('error', () => {});
});