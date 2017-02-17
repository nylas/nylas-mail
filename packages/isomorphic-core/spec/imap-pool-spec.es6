import IMAPConnectionPool from '../src/imap-pool';
import IMAPConnection from '../src/imap-connection';
import IMAPErrors from '../src/imap-errors';

describe('IMAPConnectionPool', function describeBlock() {
  beforeEach(() => {
    this.account = {
      id: 'test-account',
      decryptedCredentials: () => { return {}; },
      connectionSettings: {
        imap_host: 'imap.foobar.com',
      },
    };
    IMAPConnectionPool._poolMap = {};
    this.logger = {};
    spyOn(IMAPConnection.prototype, 'connect').and.callFake(function connectFake() {
      return this;
    });
    spyOn(IMAPConnection.prototype, 'end').and.callFake(() => {});
  });

  it('opens IMAP connection and properly returns to pool at end of scope', async () => {
    let invokedCallback = false;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 1,
      logger: this.logger,
      onConnected: ([conn]) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        invokedCallback = true;
        return false;
      },
    });
    expect(invokedCallback).toBe(true);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(1);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(0);
  });

  it('opens multiple IMAP connections and properly returns to pool at end of scope', async () => {
    let invokedCallback = false;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 2,
      logger: this.logger,
      onConnected: ([conn, otherConn]) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        expect(otherConn instanceof IMAPConnection).toBe(true);
        invokedCallback = true;
        return false;
      },
    });
    expect(invokedCallback).toBe(true);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(2);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(0);
  });

  it('opens an IMAP connection properly and only returns to pool on done', async () => {
    let invokedCallback = false;
    let doneCallback = null;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 1,
      logger: this.logger,
      onConnected: ([conn], done) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        invokedCallback = true;
        doneCallback = done;
        return true;
      },
    });
    expect(invokedCallback).toBe(true);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(1);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(0);
    expect(IMAPConnectionPool._poolMap[this.account.id]._availableConns.length === 2);
    doneCallback();
    expect(IMAPConnectionPool._poolMap[this.account.id]._availableConns.length === 3);
  });

  it('does not call connect if already connected', async () => {
    let invokedCallback = false;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 1,
      logger: this.logger,
      onConnected: ([conn]) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        invokedCallback = true;
        return false;
      },
    });
    expect(invokedCallback).toBe(true);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(1);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(0);

    invokedCallback = false;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 1,
      logger: this.logger,
      onConnected: ([conn]) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        invokedCallback = true;
        return false;
      },
    });

    expect(invokedCallback).toBe(true);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(1);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(0);
  });

  it('waits for an available IMAP connection', async () => {
    let invokedCallback = false;
    let doneCallback = null;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 3,
      logger: this.logger,
      onConnected: ([conn], done) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        invokedCallback = true;
        doneCallback = done;
        return true;
      },
    });
    expect(invokedCallback).toBe(true);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(3);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(0);

    invokedCallback = false;
    const promise = IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 1,
      logger: this.logger,
      onConnected: ([conn]) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        invokedCallback = true;
        return false;
      },
    });

    expect(IMAPConnectionPool._poolMap[this.account.id]._queue.length).toBe(1)
    doneCallback();
    await promise;

    expect(invokedCallback).toBe(true);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(3);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(0);
  });

  it('retries on IMAP connection timeout', async () => {
    let invokeCount = 0;
    await IMAPConnectionPool.withConnectionsForAccount(this.account, {
      desiredCount: 1,
      logger: this.logger,
      onConnected: ([conn]) => {
        expect(conn instanceof IMAPConnection).toBe(true);
        if (invokeCount === 0) {
          invokeCount += 1;
          throw new IMAPErrors.IMAPConnectionTimeoutError();
        }
        invokeCount += 1;
        return false;
      },
    });

    expect(invokeCount).toBe(2);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(2);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(1);
  });

  it('does not retry on other IMAP error', async () => {
    let invokeCount = 0;
    let errorCount = 0;
    try {
      await IMAPConnectionPool.withConnectionsForAccount(this.account, {
        desiredCount: 1,
        logger: this.logger,
        onConnected: ([conn]) => {
          expect(conn instanceof IMAPConnection).toBe(true);
          if (invokeCount === 0) {
            invokeCount += 1;
            throw new IMAPErrors.IMAPSocketError();
          }
          invokeCount += 1;
          return false;
        },
      });
    } catch (err) {
      errorCount += 1;
    }

    expect(invokeCount).toBe(1);
    expect(errorCount).toBe(1);
    expect(IMAPConnection.prototype.connect.calls.count()).toBe(1);
    expect(IMAPConnection.prototype.end.calls.count()).toBe(1);
  });
});
