import net from 'net';
import fs from 'fs';
import DatabaseStore from './stores/database-store';
import DatabaseChangeRecord from './stores/database-change-record';

import Utils from './models/utils';

class ActionBridgeCPP {

  constructor() {
    if (!NylasEnv.isMainWindow()) {
      // maybe bind as listener?
      return;
    }

    try {
      fs.unlinkSync('/tmp/cmail.sock');
    } catch (err) {
      console.info(err);
    }

    this.clients = [];

    // This server listens on a Unix socket at /var/run/mysocket
    const unixServer = net.createServer((c) => {
      console.log('client connected');
      this.clients.push(c);
      c.on('data', (d) => {
        this.onIncomingMessage(d.toString());
      });
      c.on('error', (err) => {
        console.log('client error', err);
      });
      c.on('timeout', () => {
        console.log('client timeout');
      });

      c.on('end', () => {
        console.log('client disconnected');
        this.clients = this.clients.filter((o) => o !== c);
      });
    });

    unixServer.listen('/tmp/cmail.sock', () => { 
      console.log('server bound');
    });

    function shutdown() {
      unixServer.close(); // socket file is automatically removed here
      process.exit();
    }

    this._readBuffer = '';
    process.on('SIGINT', shutdown);
  }

  onIncomingMessage(message) {
    this._readBuffer += message;
    const msgs = this._readBuffer.split('\n');
    this._readBuffer = msgs.pop();

    for (const msg of msgs) {
      if (msg.length === 0) {
        continue;
      }
      const {type, object, objectClass} = JSON.parse(msg, Utils.registeredObjectReviver);
      DatabaseStore.triggeringFromActionBridge = true;
      DatabaseStore.trigger(new DatabaseChangeRecord({type, objectClass, objects: [object]}));
      DatabaseStore.triggeringFromActionBridge = false;
    }
  }

  onTellClients(json) {
    const msg = JSON.stringify(json, Utils.registeredObjectReplacer);
    const headerBuffer = new Buffer(4);
    const contentBuffer = Buffer.from(msg);
    headerBuffer.fill(0);
    headerBuffer.writeUInt32LE(contentBuffer.length, 0);

    for (const c of this.clients) {
      c.write(headerBuffer);
      c.write(contentBuffer);
    }
  }

  onBeforeUnload(readyToUnload) {
    // Unfortunately, if you call ipc.send and then immediately close the window,
    // Electron won't actually send the message. To work around this, we wait an
    // arbitrary amount of time before closing the window after the last IPC event
    // was sent. https://github.com/atom/electron/issues/4366
    if (this.ipcLastSendTime && Date.now() - this.ipcLastSendTime < 100) {
      setTimeout(readyToUnload, 100);
      return false;
    }
    return true;
  }
}

export default ActionBridgeCPP;
