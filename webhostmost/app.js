const http = require('http');
const net = require('net');
const { WebSocket, createWebSocketStream } = require('ws');
const os = require('os');
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);
const { execSync } = require('child_process');
const url = require('url');

const originalUUID = process.env.UUID || '8ff07af2-df4d-4148-a644-ff4c89bddc47'; // 配置 UUID
const uuid = originalUUID.replace(/-/g, ''); //无须理会
const DOMAIN = process.env.DOMAIN || 'webhostmost.com';  //项目域名或已反代的域名，不带前缀，建议填已反代的域名
const NAME = process.env.NAME || 'webhostmost-ws'; //节点备注名称

const server = http.createServer((req, res) => {
    const parsedUrl = url.parse(req.url, true);
    const pathname = parsedUrl.pathname;

    if (pathname === '/') {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('hello world');
    } else if (pathname === '/sub') {
        const vlessURL = `vless://${originalUUID}@${DOMAIN}:443?encryption=none&security=tls&sni=${DOMAIN}&type=ws&host=${DOMAIN}&path=%2F#${NAME}`;
        const base64Content = Buffer.from(vlessURL).toString('base64');
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end(base64Content + '\n');
    } else if (pathname === '/status') {
        exec("ps -ef", { timeout: 5000 })
            .then(({ stdout }) => {
                res.writeHead(200, { 'Content-Type': 'text/html' });
                res.end("<pre>命令行执行结果：\n" + stdout + "</pre>");
            })
            .catch(err => {
                res.writeHead(200, { 'Content-Type': 'text/html' });
                res.end("<pre>命令行执行错误：\n" + err + "</pre>");
            });
    } else if (pathname === '/killall') {
        const username = os.userInfo().username;
        console.warn(`Attempting to kill all processes for user: ${username}`);
        
        exec(`pkill -u ${username}`, (error, stdout, stderr) => {
            if (error) {
                console.error(`Failed to kill processes: ${error.message}`);
                res.writeHead(500, { 'Content-Type': 'text/plain' });
                res.end(`Failed to terminate all processes: ${error.message}`);
                return;
            }
            
            console.warn(`All processes for user ${username} were terminated`);
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('All processes terminated successfully');
        });
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found\n');
    }
});

server.listen(process.env.PORT || 0, () => {
    console.log(`Server is listening on port ${server.address().port}`);
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