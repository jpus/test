const express = require("express");
const { createProxyMiddleware } = require('http-proxy-middleware');
const app = express();
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
  MONITOR_INTERVAL: 5 * 60 * 1000, // 5分钟检查一次
  WEB_SERVICE_PORT: 56789, // 转发端口
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
// 添加进程启动锁防止重复启动
let isStartingProcess = false;

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

app.get("/", (req, res) => {
  res.send("服务运行正常");
});

app.get("/status", async (req, res) => {
  try {
    const { stdout } = await exec("ps -ef", { timeout: 5000 });
    res.type("html").send("<pre>系统进程状态：\n" + stdout + "</pre>");
  } catch (err) {
    res.status(500).type("html").send("<pre>获取进程状态失败：\n" + err + "</pre>");
  }
});

if (CONFIG.ALLOW_KILLALL) {
  app.get("/killall", (req, res) => {
    const username = os.userInfo().username;
    console.warn(`警告：尝试终止用户 ${username} 的所有进程`);
    
    exec(`pkill -u ${username}`, (error, stdout, stderr) => {
      if (error) {
        console.error(`终止进程失败: ${error.message}`);
        res.status(500).send(`终止所有进程失败: ${error.message}`);
        return;
      }
      console.warn(`用户 ${username} 的所有进程已终止`);
      res.send('所有进程终止成功');
    });
  });
}

// 简化的代理中间件设置
app.use(
  "/vmess",
  createProxyMiddleware({
    target: `http://127.0.0.1:${CONFIG.WEB_SERVICE_PORT}`,
    changeOrigin: true,
    ws: true,
    pathRewrite: {
      "^/vmess": "/vmess"
    }
  })
);
console.log(`代理中间件已启用，转发到端口 ${CONFIG.WEB_SERVICE_PORT}`);

async function startServer() {
  const server = app.listen(CONFIG.PORT, () => {
    console.log(`HTTP服务正在监听端口 ${server.address().port}`);
  });  
  await runNezha();
  await runWeb();  
  monitorAndRun();
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