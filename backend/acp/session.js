import { EventEmitter } from 'node:events';
import { AgentProcess } from './rpc.js';
import { Permissions } from './permissions.js';

export class ChatSession extends EventEmitter {
  constructor({ companion, command, args, cwd, env }) {
    super();
    Object.assign(this, { companion, command, args, cwd, env });
    this.events = []; this.sequence = 0; this.tools = new Map();
    this.status = 'disconnected'; this.busy = false; this.sessionId = null;
    this.authMethods = []; this.error = ''; this.connecting = false;
    companion.on('status', () => this.emit('change'));
    companion.on('instruction', () => {
      const instruction = companion.popInstruction();
      if (!instruction) return;
      this.event('phone_instruction', { text: instruction.text });
      // Keep input visible until the user sends it; do not silently run a new
      // task or mix it into a turn already awaiting permission.
    });
  }
  event(type, data) {
    this.events.push({ sequence: ++this.sequence, type, ...data });
    if (this.events.length > 2000) this.events.shift();
    this.emit('change');
  }
  state(after = 0) {
    return { status: this.status, busy: this.busy, error: this.error, workspace: this.cwd,
      sessionId: this.sessionId, authMethods: this.authMethods, phone: this.companion.phones > 0,
      relay: this.companion.connected, push: this.companion.pushEnabled,
      pending: [...(this.permissions?.pending.values() || [])].map(e => e.card),
      events: this.events.filter(e => e.sequence > after), sequence: this.sequence };
  }
  async connect() {
    if (this.connecting || this.busy) throw new Error('Bob is already connecting or working');
    if (this.sessionId && !this.agent?.closed) return;
    this.connecting = true; this.status = 'connecting'; this.error = '';
    try {
      if (!this.agent || this.agent.closed) {
        const agent = new AgentProcess(this.command, this.args, { cwd: this.cwd, env: this.env });
        this.agent = agent;
        this.permissions = new Permissions(this.companion, agent, { changed: e => this.event(e.type, e) });
        agent.on('notification', message => this.notification(message));
        agent.on('request', message => {
          const handle = message.method === 'session/request_permission'
            ? this.permissions.request(message, this.mergeTool(message.params?.toolCall), this.sessionId)
            : agent.reject(message.id, 'Client capability not supported');
          handle.catch(error => { this.error = error.message; this.emit('change'); });
        });
        agent.on('closed', error => {
          this.permissions.cancel(); this.status = 'disconnected'; this.busy = false;
          this.sessionId = null; this.error = error.message; this.emit('change');
        });
        // Keep diagnostics local; never forward raw agent logs / login tokens.
        agent.on('diagnostic', text => {
          if (/license.*accept|accept.*license/i.test(text)) this.error = 'Bob requires license acceptance. Run Bob Shell interactively once.';
        });
        const initialized = await agent.request('initialize', {
          protocolVersion: 1, clientCapabilities: {}, clientInfo: { name: 'alice-desktop', title: 'Alice + Bob', version: '0.1.0' },
        });
        if (initialized.protocolVersion !== 1) throw new Error('Unsupported ACP version');
        this.authMethods = initialized.authMethods || [];
      }
      const session = await this.agent.request('session/new', { cwd: this.cwd, mcpServers: [] });
      this.sessionId = session.sessionId;
      if (!this.sessionId) throw new Error('Bob did not create a session');
      this.status = 'ready'; this.error = '';
      this.event('connected', { message: 'Bob is ready. Approvals are connected to Alice.' });
    } catch (error) {
      this.error = error.message;
      this.status = /license/i.test(error.message) ? 'license' : error.code === -32000 || /auth|login|sign.in/i.test(error.message) ? 'authentication' : 'setup';
      throw error;
    } finally { this.connecting = false; this.emit('change'); }
  }
  async acceptLicense() {
    if (this.busy || this.connecting || this.status !== 'license') throw new Error('No license confirmation is pending');
    this.agent?.close();
    if (!this.args.includes('--accept-license')) this.args.push('--accept-license');
    await this.connect();
  }
  async authenticate() {
    if (this.connecting || !this.agent || this.agent.closed) throw new Error('Connect to Bob first');
    const method = this.authMethods.find(m => m.id === 'sso') || this.authMethods[0];
    if (!method) throw new Error('Bob did not offer a login method');
    this.connecting = true; this.status = 'authenticating'; this.error = '';
    try { await this.agent.request('authenticate', { methodId: method.id }, 300_000); }
    catch (error) { this.status = 'authentication'; this.error = error.message; throw error; }
    finally { this.connecting = false; }
    await this.connect();
  }
  mergeTool(update) {
    if (!update?.toolCallId) return update;
    const next = { ...this.tools.get(update.toolCallId) };
    for (const [key, value] of Object.entries(update)) if (value != null) next[key] = value;
    this.tools.set(update.toolCallId, next);
    return next;
  }
  notification(message) {
    if (message.method !== 'session/update') return;
    const { sessionId, update } = message.params || {};
    if (this.sessionId && sessionId !== this.sessionId) return;
    if (!update) return;
    if (['tool_call', 'tool_call_update'].includes(update.sessionUpdate)) {
      const tool = this.mergeTool(update);
      this.permissions?.toolChanged(tool);
      this.event('tool', { tool });
    } else if (update.sessionUpdate === 'agent_message_chunk' && update.content?.type === 'text') {
      this.event('text', { text: update.content.text });
    } else if (update.sessionUpdate === 'plan') this.event('plan', { entries: update.entries });
  }
  async prompt(text) {
    if (this.busy || this.connecting || !this.sessionId || this.status !== 'ready') throw new Error('Bob is not ready for another message');
    if (typeof text !== 'string' || !text.trim() || text.length > 20_000) throw new Error('Enter a message of 1–20,000 characters');
    this.busy = true; this.error = ''; this.tools.clear();
    this.event('user', { text: text.trim() });
    try {
      const result = await this.agent.request('session/prompt', {
        sessionId: this.sessionId, prompt: [{ type: 'text', text: text.trim() }],
      }, 0);
      this.event('done', { stopReason: result.stopReason });
      this.companion.notify(result.stopReason === 'cancelled' ? 'Bob stopped.' : 'Bob finished. See the PC chat for the result.', 'info');
    } catch (error) { this.error = error.message; this.event('failure', { message: error.message }); }
    finally { this.permissions.cancel(); this.busy = false; this.emit('change'); }
  }
  async cancel() {
    this.permissions?.cancel();
    if (this.sessionId && this.agent && !this.agent.closed) await this.agent.notify('session/cancel', { sessionId: this.sessionId });
    this.event('status', { message: 'Stop requested. Waiting for Bob to finish cancelling.' });
  }
  close() { this.permissions?.cancel(); this.agent?.close(); this.companion.stop(); }
}
