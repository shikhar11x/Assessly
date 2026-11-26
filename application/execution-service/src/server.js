'use strict';

/**
 * Isolated execution service. Runs untrusted Python in a throwaway process
 * with CPU time, memory, process-count and output limits, as an unprivileged uid.
 * Protocol: POST /execute { code, input, timeoutMs } -> { status, stdout, stderr, exitCode, durationMs }
 * status: ok | runtime_error | timeout | output_limit
 */
const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs/promises');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT, 10) || 4000;
const TOKEN = process.env.EXECUTOR_TOKEN;
const SANDBOX_UID = parseInt(process.env.SANDBOX_UID, 10) || 10002;
const MAX_OUTPUT_BYTES = 64 * 1024;
const MAX_STDERR_BYTES = 4 * 1024;
const MAX_CODE_CHARS = 20000;
const MAX_INPUT_CHARS = 10000;
const MAX_BODY_BYTES = 100 * 1024;
const MAX_TIMEOUT_MS = 10000;
const MAX_CONCURRENT = 2;
let running = 0;

if (!TOKEN && process.env.NODE_ENV !== 'test') {
  console.error('EXECUTOR_TOKEN is required');
  process.exit(1);
}

function authorized(req) {
  const got = Buffer.from(String(req.headers['x-executor-token'] || ''));
  const want = Buffer.from(TOKEN || '');
  return want.length > 0 && got.length === want.length && crypto.timingSafeEqual(got, want);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY_BYTES) { reject(new Error('Payload too large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch (e) { reject(new Error('Invalid JSON')); }
    });
    req.on('error', reject);
  });
}

/** Runs one Python program. Never throws for student errors, only returns a status. */
async function runPython({ code, input = '', timeoutMs = 3000 }) {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'run-'));
  await fs.chmod(dir, 0o755);
  await fs.writeFile(path.join(dir, 'main.py'), code, { mode: 0o644 });
  const started = Date.now();
  try {
    return await new Promise((resolve) => {
      const opts = {
        cwd: dir,
        detached: true, // own process group so we can kill every child it forks
        stdio: ['pipe', 'pipe', 'pipe'],
        env: { PATH: '/usr/local/bin:/usr/bin:/bin', PYTHONIOENCODING: 'utf-8', PYTHONDONTWRITEBYTECODE: '1' },
      };
      if (process.getuid && process.getuid() === 0) { opts.uid = SANDBOX_UID; opts.gid = SANDBOX_UID; }
      // ulimit -v: 256 MB address space. ulimit -u: max processes for the sandbox uid.
      const child = spawn('/bin/sh',
        ['-c', 'ulimit -t 20; ulimit -v 262144; ulimit -u 64 2>/dev/null; exec python3 -I -B main.py'], opts);

      let stdout = '';
      let stderr = '';
      let timedOut = false;
      let flooded = false;
      const killGroup = () => { try { process.kill(-child.pid, 'SIGKILL'); } catch (e) { /* already gone */ } };
      const timer = setTimeout(() => { timedOut = true; killGroup(); }, timeoutMs);

      child.stdout.on('data', (d) => {
        if (stdout.length + d.length > MAX_OUTPUT_BYTES) {
          flooded = true;
          stdout += d.toString('utf8').slice(0, Math.max(0, MAX_OUTPUT_BYTES - stdout.length));
          killGroup();
        } else {
          stdout += d.toString('utf8');
        }
      });
      child.stderr.on('data', (d) => { if (stderr.length < MAX_STDERR_BYTES) stderr += d.toString('utf8'); });
      child.stdin.on('error', () => {});
      child.stdin.end(input);
      child.on('error', (err) => {
        clearTimeout(timer);
        resolve({ status: 'runtime_error', stdout: '', stderr: `Could not start: ${err.message}`, exitCode: null, durationMs: Date.now() - started });
      });
      child.on('close', (exitCode) => {
        clearTimeout(timer);
        killGroup(); // make sure no forked children survive
        let status = 'ok';
        if (timedOut) status = 'timeout';
        else if (flooded) status = 'output_limit';
        else if (exitCode !== 0) status = 'runtime_error';
        resolve({ status, stdout, stderr: stderr.slice(0, MAX_STDERR_BYTES), exitCode, durationMs: Date.now() - started });
      });
    });
  } finally {
    await fs.rm(dir, { recursive: true, force: true }).catch(() => {});
  }
}

function createServer() {
  return http.createServer(async (req, res) => {
    const send = (status, obj) => {
      const body = JSON.stringify(obj);
      res.writeHead(status, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
      res.end(body);
    };
    if (req.method === 'GET' && req.url === '/health') return send(200, { status: 'ok', running });
    if (req.method === 'POST' && req.url === '/execute') {
      if (!authorized(req)) return send(401, { error: 'Unauthorized' });
      let body;
      try { body = await readJson(req); } catch (e) { return send(400, { error: e.message }); }
      if (typeof body.code !== 'string' || !body.code.length || body.code.length > MAX_CODE_CHARS) {
        return send(400, { error: `code must be a string of 1-${MAX_CODE_CHARS} characters` });
      }
      const input = body.input === undefined ? '' : body.input;
      if (typeof input !== 'string' || input.length > MAX_INPUT_CHARS) return send(400, { error: 'input must be a short string' });
      const timeoutMs = Math.min(Math.max(Number(body.timeoutMs) || 3000, 500), MAX_TIMEOUT_MS);
      if (running >= MAX_CONCURRENT) return send(429, { error: 'Executor busy' });
      running += 1;
      try {
        return send(200, await runPython({ code: body.code, input, timeoutMs }));
      } catch (err) {
        console.error(err);
        return send(500, { error: 'Internal error' });
      } finally {
        running -= 1;
      }
    }
    return send(404, { error: 'Not Found' });
  });
}

module.exports = { createServer, runPython };

if (require.main === module) {
  const server = createServer().listen(PORT, () => console.log(`Execution service listening on ${PORT}`));
  const stop = () => server.close(() => process.exit(0));
  process.on('SIGTERM', stop);
  process.on('SIGINT', stop);
}
