const http = require('http');
const httpProxy = require('http-proxy');
const net = require('net');
const axios = require("axios");
const os = require('os');
const fs = require("fs");
const path = require("path");
const { promisify } = require('util');
const exec = promisify(require('child_process').exec);
const { execSync } = require('child_process');

const CONFIG = {
  NEZHA_KEY: process.env.NEZHA_KEY || '66vIsRM7Ex0mSK2VpP',
  PORT: process.env.PORT || 3000,
  MONITOR_INTERVAL: 5 * 60 * 1000,
  WEB_SERVICE_PORT: 56789,
  DOWNLOAD_TIMEOUT: 30000,
  BINARY_PERMISSIONS: 0o755,
  ALLOW_KILLALL: true 
};

function getSystemArchitecture() {
  const arch = os.arch();
  return ['arm', 'arm64', 'aarch64'].includes(arch) ? 'arm' : 'amd';
}

function getDownloadUrls() {
  const architecture = getSystemArchitecture();
  return architecture === 'arm' ? {
    npm: "https://github.com/eooce/test/releases/download/ARM/swith",
    web: "https://github.com/eooce/test/releases/download/ARM/web",
  } : {
    npm: "https://github.com/jpus/test/releases/download/web/nza-9",
    web: "https://github.com/jpus/test/releases/download/web/x56789m-9",
  };
}

async function isProcessRunning(processName) {
  try {
    if (processName === 'npm') {
      const cmd = `ps -eo pid,cmd | grep -E "[n]pm -p ${CONFIG.NEZHA_KEY}" || true`;
      const { stdout } = await exec(cmd);
      return stdout.trim().length > 0;
    } else if (processName === 'web') {
      const cmd = `ps -eo pid,cmd | grep -E "[w]web" || true`;
      const { stdout } = await exec(cmd);
      return stdout.trim().length > 0;
    } else {
      const { stdout } = await exec(`pgrep -x ${processName}`);
      return stdout.trim().length > 0;
    }
  } catch {
    return false;
  }
}

async function startProcess(processName, command) {
  try {
    console.log(`启动 ${processName} 进程...`);
    await exec(command);
    console.log(`${processName} 启动成功`);
    return true;
  } catch (err) {
    console.error(`${processName} 启动失败:`, err);
    return false;
  }
}

async function downloadFile(fileName, fileUrl) {
  const filePath = path.join(__dirname, fileName);
  
  if (fs.existsSync(filePath)) {
    console.log(`文件 ${fileName} 已存在`);
    return filePath;
  }

  console.log(`开始下载 ${fileName}...`);
  const writer = fs.createWriteStream(filePath);
  
  try {
    const response = await axios({
      url: fileUrl,
      method: 'GET',
      responseType: 'stream',
      timeout: CONFIG.DOWNLOAD_TIMEOUT
    });

    response.data.pipe(writer);

    await new Promise((resolve, reject) => {
      writer.on('finish', resolve);
      writer.on('error', reject);
    });

    console.log(`${fileName} 下载完成`);
    await fs.promises.chmod(filePath, CONFIG.BINARY_PERMISSIONS);
    return filePath;
  } catch (err) {
    if (fs.existsSync(filePath)) {
      await fs.promises.unlink(filePath);
    }
    throw new Error(`下载 ${fileName} 失败: ${err.message}`);
  }
}

async function ensureFile(fileName, fileUrl) {
  try {
    if (!fs.existsSync(fileName)) {
      console.log(`文件 ${fileName} 不存在，尝试下载...`);
      await downloadFile(fileName, fileUrl);
    }
    return true;
  } catch (err) {
    console.error(`文件 ${fileName} 确保失败:`, err);
    return false;
  }
}

async function runNezha() {
  if (!CONFIG.NEZHA_KEY) {
    console.error('未配置NEZHA_KEY，跳过哪吒监控启动');
    return false;
  }

  const urls = getDownloadUrls();
  if (!await ensureFile('npm', urls.npm)) return false;

  return startProcess('哪吒监控', `nohup ./npm -p ${CONFIG.NEZHA_KEY} >/dev/null 2>&1 &`);
}

async function runWeb() {
  const urls = getDownloadUrls();
  if (!await ensureFile('web', urls.web)) return false;

  return startProcess('Web服务', `nohup ./web >/dev/null 2>&1 &`);
}

async function monitorAndRun() {
  const urls = getDownloadUrls();
  
  setInterval(async () => {
    console.log('\n[监控周期开始]');
    
    if (!(await isProcessRunning('npm'))) {
      console.log('哪吒监控未运行，尝试重启...');
      await ensureFile('npm', urls.npm);
      await runNezha();
    }

    if (!(await isProcessRunning('web'))) {
      console.log('Web服务未运行，尝试重启...');
      await ensureFile('web', urls.web);
      await runWeb();
    }

    console.log('[监控周期结束]');
  }, CONFIG.MONITOR_INTERVAL);
}

function createServer() {
  const proxy = httpProxy.createProxyServer({
    target: `http://127.0.0.1:${CONFIG.WEB_SERVICE_PORT}`,
    ws: true
  });

  proxy.on('error', (err, req, res) => {
    console.error(`[Proxy Error] ${err.code || 'UNKNOWN'}`, err.message);
    
    if (!res.headersSent) {
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        error: "代理服务发生错误",
        code: err.code || 'UNKNOWN'
      }));
    }
  });

  const server = http.createServer(async (req, res) => {
    console.log(`[HTTP] ${req.method} ${req.url}`);

    if (req.url === '/') {
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end('服务运行正常');
      return;
    }

    if (req.url === '/status') {
      try {
        const { stdout } = await exec("ps -ef", { timeout: 5000 });
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end("<pre>系统进程状态：\n" + stdout + "</pre>");
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'text/html' });
        res.end("<pre>获取进程状态失败：\n" + err + "</pre>");
      }
      return;
    }

    if (CONFIG.ALLOW_KILLALL && req.url === '/killall') {
      const username = os.userInfo().username;
      console.warn(`警告：尝试终止用户 ${username} 的所有进程`);
      
      exec(`pkill -u ${username}`, (error) => {
        if (error) {
          console.error(`终止进程失败: ${error.message}`);
          res.writeHead(500, { 'Content-Type': 'text/plain' });
          res.end(`终止所有进程失败: ${error.message}`);
          return;
        }
        console.warn(`用户 ${username} 的所有进程已终止`);
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('所有进程终止成功');
      });
      return;
    }

    proxy.web(req, res);
  });

  server.on('upgrade', (req, socket, head) => {
    console.log(`[WebSocket] 升级连接 ${req.url}`);
    proxy.ws(req, socket, head);
  });

  return server;
}

async function startServer() {
  console.log('=== 服务启动开始 ===');

  const server = createServer();
  
  server.listen(CONFIG.PORT, () => {
    console.log(`HTTP服务正在监听端口 ${CONFIG.PORT}`);
  });

  await runNezha();
  await runWeb();
  
  monitorAndRun();

  console.log('=== 服务启动完成 ===');
}

process.on('unhandledRejection', (err) => {
  console.error('未处理的Promise拒绝:', err);
});

process.on('uncaughtException', (err) => {
  console.error('未捕获的异常:', err);
  process.exit(1);
});

startServer().catch(err => {
  console.error('启动失败:', err);
  process.exit(1);
});