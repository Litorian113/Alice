import { EventEmitter } from 'node:events';
import { spawn } from 'node:child_process';

// ACP stdio: one JSON-RPC message per UTF-8 line, in both directions.
export class AgentProcess extends EventEmitter {
  constructor(command, args, { cwd, env = process.env } = {}) {
    super();
    this.nextId = 0;
    this.pending = new Map();
    this.closed = false;
    this.child = spawn(command, args, { cwd, env, stdio: ['pipe', 'pipe', 'pipe'] });
    let buffer = '';
    this.child.stdout.setEncoding('utf8');
    this.child.stdout.on('data', chunk => {
      buffer += chunk;
      if (buffer.length > 8 * 1024 * 1024) return this.fail(new Error('ACP message exceeds 8 MB'));
      let end;
      while ((end = buffer.indexOf('\n')) >= 0) {
        const line = buffer.slice(0, end); buffer = buffer.slice(end + 1);
        if (!line.trim()) continue;
        let message;
        try { message = JSON.parse(line); }
        catch { this.fail(new Error('Bob wrote invalid ACP data')); return; }
        if (message.jsonrpc !== '2.0') { this.fail(new Error('Invalid ACP envelope')); return; }
        if (message.method) {
          this.emit(message.id === undefined ? 'notification' : 'request', message);
        } else {
          const request = this.pending.get(message.id);
          if (!request) continue;
          this.pending.delete(message.id); clearTimeout(request.timer);
          if (message.error) {
            const error = new Error(message.error.message || 'ACP request failed');
            error.code = message.error.code; error.data = message.error.data;
            request.reject(error);
          } else request.resolve(message.result);
        }
      }
    });
    this.child.stderr.setEncoding('utf8');
    this.child.stderr.on('data', text => this.emit('diagnostic', text));
    this.child.stdin.on('error', error => this.fail(error));
    this.child.on('error', error => this.fail(error));
    this.child.on('exit', (code, signal) => this.fail(new Error(`Bob stopped (${signal || code})`)));
  }

  write(message) {
    if (this.closed || this.child.stdin.destroyed) return Promise.reject(new Error('Bob is disconnected'));
    return new Promise((resolve, reject) => this.child.stdin.write(JSON.stringify({ jsonrpc: '2.0', ...message }) + '\n', error => error ? reject(error) : resolve()));
  }

  request(method, params, timeout = 60_000) {
    const id = ++this.nextId;
    return new Promise((resolve, reject) => {
      const timer = timeout ? setTimeout(() => {
        this.pending.delete(id); reject(new Error(`Bob timed out: ${method}`));
      }, timeout) : undefined;
      this.pending.set(id, { resolve, reject, timer });
      this.write({ id, method, params }).catch(error => {
        clearTimeout(timer); this.pending.delete(id); reject(error);
      });
    });
  }

  notify(method, params) { return this.write({ method, params }); }
  respond(id, result) { return this.write({ id, result }); }
  reject(id, message) { return this.write({ id, error: { code: -32601, message } }); }

  fail(error) {
    if (this.closed) return;
    this.closed = true;
    for (const request of this.pending.values()) { clearTimeout(request.timer); request.reject(error); }
    this.pending.clear();
    this.emit('closed', error);
    this.child.kill();
  }
  close() { this.fail(new Error('Bob connection closed')); }
}
