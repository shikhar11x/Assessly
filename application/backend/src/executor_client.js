'use strict';

require('./config'); // loads .env
const TIMEOUT_GRACE_MS = 3000;

class ExecutorUnavailable extends Error {}

/** Sends code to the isolated execution service. Throws ExecutorUnavailable if it cannot answer. */
async function runCode({ code, input = '', timeoutMs = 3000 }) {
  const url = process.env.EXECUTOR_URL || 'http://127.0.0.1:4000';
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs + TIMEOUT_GRACE_MS);
  try {
    const res = await fetch(`${url}/execute`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Executor-Token': process.env.EXECUTOR_TOKEN || '' },
      body: JSON.stringify({ code, input, timeoutMs }),
      signal: ctrl.signal,
    });
    if (res.status === 429) throw new ExecutorUnavailable('The execution service is busy, try again in a moment');
    if (!res.ok) throw new ExecutorUnavailable(`Execution service error (${res.status})`);
    return await res.json();
  } catch (err) {
    if (err instanceof ExecutorUnavailable) throw err;
    throw new ExecutorUnavailable('The execution service is unreachable');
  } finally {
    clearTimeout(timer);
  }
}

module.exports = { runCode, ExecutorUnavailable };
