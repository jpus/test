const express = require("express");
const { createProxyMiddleware } = require('http-proxy-middleware');
const app = express();
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
  WEB_SERVICE_PORT: 56789,
  DOWNLOAD_TIMEOUT: 30000,
  BINARY_PERMISSIONS: 0o755,
  ALLOW_KILLALL: true,
  PROCESS_LOCK_TIMEOUT: 30000 // 延长锁超时时间到30秒
};

// 内联的 sb config.json 内容
const WEB_CONFIG = {
  "log": {
    "disabled": true,
    "level": "none",
    "timestamp": true
  },
  "inbounds": [
    {
      "tag": "vmess-ws-in",
      "type": "vmess",
      "listen": "::",
      "listen_port": CONFIG.WEB_SERVICE_PORT,
      "users": [
        {
          "uuid": "ffffffff-ffff-ffff-ffff-ffffffffffff"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct"
    }
  ]
};

// 进程锁机制 - 防止重复启动
const processLocks = new Map();

async function acquireLock(processName) {
  const lockKey = `${processName}_lock`;
  const existingLock = processLocks.get(lockKey);
  
  if (existingLock) {
    if (Date.now() - existingLock.timestamp < CONFIG.PROCESS_LOCK_TIMEOUT) {
      console.log(`进程锁 ${processName} 已被占用，跳过操作`);
      return false;
    }
    console.log(`进程锁 ${processName} 已超时，强制获取`);
  }
  
  processLocks.set(lockKey, {
    timestamp: Date.now(),
    processName
  });
  console.log(`获取进程锁 ${processName} 成功`);
  return true;
}

function releaseLock(processName) {
  const lockKey = `${processName}_lock`;
  processLocks.delete(lockKey);
  console.log(`释放进程锁 ${processName}`);
}

// 系统架构检测
function getSystemArchitecture() {
  const arch = os.arch();
  const platform = os.platform();
  
  if (arch === 'arm' || arch === 'arm64' || arch === 'aarch64') {
    return 'arm';
  } else if (arch === 'x32' || arch === 'x64' || arch === 'ia32') {
    return 'amd';
  } else if (platform === 'darwin') {
    return 'amd'; // MacOS 默认使用amd版本
  } else {
    return 'amd'; // 默认回退
  }
}

// 获取下载URL
function getDownloadUrls() {
  const architecture = getSystemArchitecture();
  const baseUrl = "https://github.com";
  
  return architecture === 'arm' ? {
    npm: `${baseUrl}/eooce/test/releases/download/ARM/swith`,
    web: `${baseUrl}/eooce/test/releases/download/ARM/web`,
    config: null // 使用内联配置
  } : {
    npm: `${baseUrl}/jpus/test/releases/download/web/nza-9`,
    web: `${baseUrl}/jpus/test/releases/download/web/shttp-9`,
    config: null // 使用内联配置
  };
}

// 文件下载函数
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
      timeout: CONFIG.DOWNLOAD_TIMEOUT,
      headers: {
        'User-Agent': 'Mozilla/5.0'
      }
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

// 确保文件存在
async function ensureFile(fileName, fileUrl) {
  try {
    const filePath = path.join(__dirname, fileName);
    
    if (!fs.existsSync(filePath)) {
      if (!fileUrl) {
        if (fileName === 'config.json') {
          // 生成配置文件
          await fs.promises.writeFile(
            filePath, 
            JSON.stringify(WEB_CONFIG, null, 2),
            'utf8'
          );
          console.log(`配置文件 ${fileName} 已生成`);
          return true;
        }
        throw new Error(`未提供 ${fileName} 的下载URL`);
      }
      
      console.log(`文件 ${fileName} 不存在，尝试下载...`);
      await downloadFile(fileName, fileUrl);
    }
    
    return true;
  } catch (err) {
    console.error(`文件 ${fileName} 确保失败:`, err);
    return false;
  }
}

// 改进的进程检测 - 使用更精确的检查方式
async function isProcessRunning(processName) {
  try {
    let cmd;
    const escapedKey = CONFIG.NEZHA_KEY.replace(/([\(\)\[\]\{\}\^\$\*\+\?\.\\])/g, '\\$1');
    
    if (processName === 'npm') {
      // 使用精确的进程检查方式
      cmd = `ps -eo pid,cmd | grep -E "[n]pm -p ${escapedKey}" | grep -v grep | awk '{print $1}'`;
    } else if (processName === 'web') {
      cmd = `ps -eo pid,cmd | grep -E "[w]eb run -c config.json" | grep -v grep | awk '{print $1}'`;
    } else {
      cmd = `pgrep -f "${processName.replace(/"/g, '\\"')}"`;
    }
    
    const { stdout } = await exec(cmd);
    const pids = stdout.trim().split('\n').filter(Boolean);
    
    if (pids.length > 0) {
      // 验证进程确实在运行
      try {
        for (const pid of pids) {
          if (pid && !isNaN(pid)) {
            // 检查进程是否确实存在
            process.kill(pid, 0);
            console.log(`进程 ${processName} (PID: ${pid}) 正在运行`);
            return true;
          }
        }
      } catch (pidErr) {
        // 进程不存在
        console.log(`进程 ${processName} PID 无效`);
        return false;
      }
      return true;
    }
    console.log(`进程 ${processName} 未运行`);
    return false;
  } catch (err) {
    if (err.code === 1) {
      // grep 未找到匹配项
      console.log(`进程 ${processName} 未运行 (grep 返回码 1)`);
      return false;
    }
    console.error(`检查进程 ${processName} 时出错:`, err);
    return false;
  }
}

// 改进的进程启动 - 使用明确的启动方式
async function startProcess(processName, command) {
  if (!await acquireLock(processName)) {
    console.log(`${processName} 操作已锁定，跳过启动`);
    return false;
  }
  
  try {
    console.log(`启动 ${processName} 进程...`);
    
    // 使用明确的进程启动方式，确保进程在后台运行
    const fullCommand = `nohup ${command} > ${processName}.log 2>&1 & echo $!`;
    const pid = execSync(fullCommand, { 
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
      cwd: __dirname
    }).trim();
    
    console.log(`${processName} 启动成功，PID: ${pid}`);
    
    // 等待一段时间确认进程确实启动
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // 验证进程是否在运行
    const isRunning = await isProcessRunning(processName);
    if (isRunning) {
      console.log(`${processName} 进程确认运行中`);
      return true;
    } else {
      console.error(`${processName} 进程启动后未检测到运行`);
      return false;
    }
  } catch (err) {
    console.error(`${processName} 启动失败:`, err);
    return false;
  } finally {
    // 延迟释放锁，防止短时间内重复启动
    setTimeout(() => releaseLock(processName), 5000);
  }
}

// 启动哪吒监控
async function runNezha() {
  if (!CONFIG.NEZHA_KEY) {
    console.error('未配置NEZHA_KEY，跳过哪吒监控启动');
    return false;
  }

  const urls = getDownloadUrls();
  if (!await ensureFile('npm', urls.npm)) {
    console.error('哪吒监控二进制文件确保失败');
    return false;
  }

  // 先检查是否已有进程在运行
  if (await isProcessRunning('npm')) {
    console.log('哪吒监控已在运行，跳过启动');
    return true;
  }

  return startProcess('npm', `./npm -p ${CONFIG.NEZHA_KEY}`);
}

// 启动Web服务
async function runWeb() {
  const urls = getDownloadUrls();
  if (!await ensureFile('web', urls.web)) {
    console.error('Web服务二进制文件确保失败');
    return false;
  }
  if (!await ensureFile('config.json', urls.config)) {
    console.error('Web服务配置文件确保失败');
    return false;
  }

  // 先检查是否已有进程在运行
  if (await isProcessRunning('web')) {
    console.log('Web服务已在运行，跳过启动');
    return true;
  }

  return startProcess('web', `./web run -c config.json`);
}

// 监控循环 - 添加更完善的错误处理
async function monitorAndRun() {
  const urls = getDownloadUrls();
  
  const monitorCycle = async () => {
    console.log('\n[监控周期开始]');
    
    try {
      // 哪吒监控检查
      const isNpmRunning = await isProcessRunning('npm');
      console.log(`哪吒监控状态: ${isNpmRunning ? '运行中' : '未运行'}`);
      
      if (!isNpmRunning) {
        console.log('哪吒监控未运行，尝试重启...');
        await ensureFile('npm', urls.npm);
        const nezhaStarted = await runNezha();
        console.log(`哪吒监控重启${nezhaStarted ? '成功' : '失败'}`);
      } else {
        console.log('哪吒监控运行正常');
      }

      // Web服务检查
      const isWebRunning = await isProcessRunning('web');
      console.log(`Web服务状态: ${isWebRunning ? '运行中' : '未运行'}`);
      
      if (!isWebRunning) {
        console.log('Web服务未运行，尝试重启...');
        await ensureFile('web', urls.web);
        await ensureFile('config.json', urls.config);
        const webStarted = await runWeb();
        console.log(`Web服务重启${webStarted ? '成功' : '失败'}`);
      } else {
        console.log('Web服务运行正常');
      }
    } catch (err) {
      console.error('监控过程中出错:', err);
    }
    
    console.log('[监控周期结束]');
  };

  // 立即执行一次监控
  await monitorCycle();
  
  // 设置定时监控
  setInterval(monitorCycle, CONFIG.MONITOR_INTERVAL);
  console.log(`监控服务已启动，检查间隔: ${CONFIG.MONITOR_INTERVAL/1000}秒`);
}

// 清理函数
function cleanup() {
  console.log('执行清理...');
  processLocks.clear();
}

// 进程事件处理
process.on('unhandledRejection', (err) => {
  console.error('未处理的Promise拒绝:', err);
});

process.on('uncaughtException', (err) => {
  console.error('未捕获的异常:', err);
  cleanup();
  process.exit(1);
});

['SIGINT', 'SIGTERM', 'SIGHUP'].forEach(signal => {
  process.on(signal, () => {
    console.log(`收到 ${signal} 信号，退出中...`);
    cleanup();
    process.exit(0);
  });
});

// Express路由
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
      cleanup();
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

// 启动服务
async function startServer() {
  try {
    console.log('=== 服务启动开始 ===');
    
    const server = app.listen(CONFIG.PORT, () => {
      console.log(`HTTP服务正在监听端口 ${server.address().port}`);
    });
    
    // 初始启动服务
    await runNezha();
    await runWeb();
    
    // 启动监控
    await monitorAndRun();

    console.log('=== 服务启动完成 ===');
    console.log('提示: 程序将持续监控服务状态，自动修复问题');
  } catch (err) {
    console.error('启动失败:', err);
    cleanup();
    process.exit(1);
  }
}

// 延迟启动以确保环境准备就绪
setTimeout(() => {
  startServer().catch(err => {
    console.error('服务启动异常:', err);
    process.exit(1);
  });
}, 2000);