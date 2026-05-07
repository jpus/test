const express = require("express");
const app = express();
const net = require('net');
const { WebSocket, createWebSocketStream } = require('ws');

const originalUUID = process.env.UUID || 'ffffffff-ffff-ffff-ffff-ffffffffffff';
const uuid = originalUUID.replace(/-/g, '');
const DOMAIN = process.env.DOMAIN || 'webfreecloud.去你大爷.nyc.mn';  //项目域名或已反代的域名，不带前缀，建议填已反代的域名
const NAME = process.env.NAME || 'webfreecloud-ws'; //备注名称
const SUB_PATH = process.env.SUB_PATH || UUID.slice(0, 8); //自动获取uuid前8位作为订阅路径，可修改例如'sub'

app.get("/", (req, res) => {
  res.send("hello world");
}); // 创建 HTTP 服务器

app.get("/${SUB_PATH}", (req, res) => {
  const vlessURL = `vless://${originalUUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F#${NAME}`;
  
  const base64Content = Buffer.from(vlessURL).toString('base64');

  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(base64Content + '\n');
});

app.use((req, res) => {
  res.status(404).type('text/plain').end('Not Found\n');
}); // 统一使用res.status().send()格式 处理其他路由


const server = app.listen(process.env.PORT || 0, () => {
  console.log(`Server is listening`);
}); // 启动 HTTP 服务器（不指定端口，由平台自动分配）

const wss = new WebSocket.Server({ server }); // 创建 WebSocket 服务器，复用 HTTP 的 server

wss.on('connection', (ws) => {
  ws.once('message', (msg) => {
    const [VERSION] = msg;
    const id = msg.slice(1, 17);

    // 检查 UUID 是否匹配
    if (!id.every((v, i) => v == parseInt(uuid.substr(i * 2, 2), 16))) {
      return;
    }

    let i = msg.slice(17, 18).readUInt8() + 19;
    const port = msg.slice(i, (i += 2)).readUInt16BE(0);
    const ATYP = msg.slice(i, (i += 1)).readUInt8();

    // 解析目标主机（IPv4 / 域名 / IPv6）
    const host =
      ATYP == 1
        ? msg.slice(i, (i += 4)).join('.') // IPv4
        : ATYP == 2
        ? new TextDecoder().decode(msg.slice(i + 1, (i += 1 + msg.slice(i, i + 1).readUInt8()))) // 域名
        : ATYP == 3
        ? msg.slice(i, (i += 16)).reduce((s, b, i, a) => (i % 2 ? s.concat(a.slice(i - 1, i + 1)) : s), [])
            .map((b) => b.readUInt16BE(0).toString(16))
            .join(':') // IPv6
        : '';
    
    ws.send(new Uint8Array([VERSION, 0])); // 返回成功响应（VERSION + 0x00）

    const duplex = createWebSocketStream(ws); // 创建 WebSocket 双工流

    // 连接目标服务器（host:port）
    net.connect({ host, port }, function () {
      this.write(msg.slice(i)); // 发送剩余数据
      duplex
        .on('error', () => {}) // 忽略错误
        .pipe(this)
        .on('error', () => {}) // 忽略错误
        .pipe(duplex);
    }).on('error', () => {}); // 忽略连接错误
  }).on('error', () => {}); // 忽略 WebSocket 错误
});