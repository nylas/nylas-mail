import moment from 'moment'
import {Errors, IMAPConnectionPool} from 'isomorphic-core'
import {GmailOAuthHelpers} from 'cloud-core'

const DEFAULT_SOCKET_TIMEOUT = +(process.env.DEFAULT_SOCKET_TIMEOUT || 5 * 60 * 1000);
const RETRY_BASE_SEC = +(process.env.RETRY_BASE_SEC || 5);

export default class CloudWorker {
  constructor(cloudJob, {db, logger}) {
    this.job = cloudJob
    this.db = db
    this.initLogger = logger.child({
      jobId: cloudJob.id,
      accountId: cloudJob.accountId,
      contextClass: this.constructor.name,
      contextType: "Worker",
    }); // Should be a child of Foreman's logger
  }

  async run() {
    try {
      const account = await this.db.Account.findById(this.job.accountId);
      if (!this.logger) {
        this.logger = this.initLogger.child({
          email: account.emailAddress,
          provider: account.provider,
        })
      }

      this.logger.info(`Running ${this.constructor.name}. Initial status: ${this.job.status}. Attempt number: ${this.job.attemptNumber}`);

      await this._markInProgress();
      await this._ensureAccessToken(account)
      await IMAPConnectionPool.withConnectionsForAccount(account, {
        logger: this.logger,
        desiredCount: 1,
        socketTimeout: DEFAULT_SOCKET_TIMEOUT,
        onConnected: async ([connection]) => {
          await this._runWithConnection({connection, account})
        },
      })
    } catch (err) {
      await this._onError(err)
    }
  }

  async _runWithConnection({connection, account}) {
    const metadatum = await this.db.Metadata.findById(this.job.metadataId);
    if (!metadatum) {
      this.logger.error(`Can't find metadata ${this.job.metadataId} for job: ${this.job.id}`)
      throw new Error("Can't find metadata")
    }
    await this.performAction({metadatum, account, connection});
    await this.db.CloudJob.update(
      {status: "SUCCEEDED", statusUpdatedAt: new Date()},
      {where: {id: this.job.id}}
    );
    this.logger.info(`${this.constructor.name} Succeeded`)
  }

  async _onError(err) {
    return this.db.sequelize.transaction(async (t) => {
      const job = await this.db.CloudJob.findById(this.job.id, {transaction: t});
      job.error = {
        message: err.message,
        name: err.constructor.name,
        stack: err.stack,
      }
      if (err instanceof Errors.RetryableError) {
        job.status = "WAITING-TO-RETRY";
        const sec = RETRY_BASE_SEC * (2 ** job.attemptNumber);
        job.retryAt = moment().add(sec, 'seconds').toDate();
        this.logger.info(`Failed with a retryable error. Will retry in ${sec} seconds around ${job.retryAt}`)
      } else {
        job.status = "FAILED"
        this.logger.info(`Failed with a permanent error`)
      }
      job.statusUpdatedAt = new Date()
      await job.save({transaction: t});
      this.logger.error(err)
    })
  }

  async _ensureAccessToken(account) {
    const currentUnixDate = Math.floor(Date.now() / 1000);
    const credentials = account.decryptedCredentials()
    if (account.provider === 'gmail') {
      if (!credentials.xoauth2 || !credentials.expiry_date ||
          currentUnixDate > credentials.expiry_date) {
        this.logger.info(`Refreshing access token for account id: ${account.id}`);
        await GmailOAuthHelpers.refreshAccessToken(account);
      }
    }
  }

  async _markInProgress() {
    return this.db.sequelize.transaction(async (t) => {
      const job = await this.db.CloudJob.findById(this.job.id, {transaction: t});
      job.status = "INPROGRESS-RETRYABLE";
      job.statusUpdatedAt = new Date();
      const attemptNum = job.attemptNumber;
      job.attemptNumber = attemptNum + 1; // beware magic setter method
      await job.save({transaction: t})
    })
  }

  pluginId() {
    throw new Error("You should override this!");
  }

  async performAction() {
    throw new Error("You should override this!");
  }
}
