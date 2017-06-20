import _ from 'underscore';
import net from 'net';
import fs from 'fs';
import Actions from './actions';
import DatabaseStore from './stores/database-store';
import DatabaseChangeRecord from './stores/database-change-record';

import Utils from './models/utils';

const Message = {
  DATABASE_STORE_TRIGGER: 'db-store-trigger',
};

const printToConsole = false;

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

    // This server listens on a Unix socket at /var/run/mysocket
    const unixServer = net.createServer((c) => {
      // Do something with the client connection
      console.log('client connected');
      c.on('data', (d) => {
        this.onIncomingMessage(d.toString());
      });
      c.on('end', () => {
        console.log('client disconnected');
      });
      c.write('hello\r\n');
      c.pipe(c);
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
    console.log(message);
    this._readBuffer += message;
    const msgs = this._readBuffer.split('\n');
    this._readBuffer = msgs.pop();

    for (const msg of msgs) {
      const {type, model} = JSON.parse(msg, Utils.registeredObjectReviver);
      DatabaseStore.triggeringFromActionBridge = true;
      DatabaseStore.trigger(new DatabaseChangeRecord({type, objects: [model]}));
      DatabaseStore.triggeringFromActionBridge = false;
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
