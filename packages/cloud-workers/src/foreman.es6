import moment from 'moment'
import {StatsD} from 'node-dogstatsd'
const STATSD_HOST = process.env.STATSD_HOST || "172.17.0.1"
const stats = new StatsD(STATSD_HOST, 8125)

export default class Foreman {
  constructor({db, logger, pluginId, WorkerClass}) {
    this.db = db;
    this.pluginId = pluginId
    this.WorkerClass = WorkerClass
    this.foremanId = `${this.constructor.name}-${pluginId}-${process.pid}`
    this.logger = logger.child({
      foremanId: this.foremanId,
      contextClass: this.constructor.name,
      contextType: "Foreman",
      pluginId: pluginId,
    });
    this.runTimeout = null;

    this.MAX_RETRIES = +(process.env.MAX_RETRIES || 10);
    this.MAX_METADATA_GRAB = +(process.env.MAX_METADATA_GRAB || 100);
    this.DEAD_THRESHOLD_MIN = +(process.env.DEAD_THRESHOLD_MIN || 10);
    this.MAX_JOBS_PER_FOREMAN = +(process.env.MAX_JOBS_PER_FOREMAN || 20);
    this.FOREMAN_CHECK_INTERVAL = +(process.env.FOREMAN_CHECK_INTERVAL || 10 * 1000);
  }

  async run() {
    clearTimeout(this.runTimeout);
    try {
      this.logger.info(`❤️`);
      await this.createJobsFromMetadata();
      await this.cleanupDeadJobs();
      const newJobs = await this.claimJobs();
      this.runWorkers(newJobs); // Do NOT await. Does nothing if no new jobs
      stats.gauge(`cloud-workers.heartbeat.${this.pluginId}`, 1)
    } finally {
      clearTimeout(this.runTimeout);
      this.runTimeout = setTimeout(this.run.bind(this), this.FOREMAN_CHECK_INTERVAL);
    }
  }

  stop() {
    this.logger.info(`Stopping`);
    clearTimeout(this.runTimeout);
  }

  /**
   * This kicks off the workers and we do NOT await for them. As soon as they
   * run they'll update their status in the database.
   */
  async runWorkers(newJobs = []) {
    if (newJobs.length === 0) return
    const workers = newJobs.map((job) =>
      new this.WorkerClass(job, {db: this.db, logger: this.logger})
    );
    for (const worker of workers) {
      // DO NOT await
      worker.run(); // Logging in worker
    }
  }

  /**
   * Our plugins use Metadata to record if they want some work done by the
   * `expiration` field.
   *
   * We want to as quickly as possible convert the Metadata into first class
   * `CloudJob` objects.
   */
  async createJobsFromMetadata() {
    await this.db.sequelize.transaction(async (t) => {
      const expiredMetadata = await this.db.Metadata.findAll({
        attributes: ["id", "value", "pluginId", "accountId", "expiration"],
        transaction: t,
        limit: this.MAX_METADATA_GRAB,
        where: {pluginId: this.pluginId, expiration: {$lte: new Date()}}, // Indexed
      });

      if (expiredMetadata.length === 0) {
        this.logger.debug(`No newly expired metadata`);
        return
      }

      const newJobData = expiredMetadata.map((metadatum) => {
        return {
          type: metadatum.pluginId,
          metadataId: metadatum.id,
          accountId: metadatum.accountId,
          foremanId: this.foremanId,
        }
      })

      this.logger.info(`Creating ${newJobData.length} new CloudJobs for newly expired metadata`);
      await this.db.CloudJob.bulkCreate(newJobData, {transaction: t})
      // Immediately mark Metadata as no longer expired now that we've created
      // jobs for them
      for (const expiredMetadatum of expiredMetadata) {
        try {
          await expiredMetadatum.clearExpiration({transaction: t})
        } catch (err) {
          this.logger.error(err);
          this.logger.info("Deleting corrupted metadata");
          await expiredMetadatum.destroy();
        }
      }
    })
  }

  /**
   * In a single transaction this will grab available jobs for the plugin
   * across the whole DB, and mark them as started.
   *
   * We claim both new jobs for the plugin
   * AND
   * We claim jobs that are in progress but claimed a long time ago, likely
   * indicating that they died and need to be retried.
   */
  async claimJobs() {
    let claimableJobs = []
    await this.db.sequelize.transaction(async (t) => {
      claimableJobs = await this.db.CloudJob.findAll({
        transaction: t,
        limit: await this.currentJobLimit(t),
        where: {
          $or: [
            // New jobs.
            {type: this.pluginId, status: "NEW"}, // Indexed!
            // Failed, but retryable jobs.
            {
              type: this.pluginId, // indexed
              status: "WAITING-TO-RETRY", // indexed
              attemptNumber: {$lt: this.MAX_RETRIES}, // indexed
              retryAt: {$lte: new Date()}, // NOT indexed
            }, // Indexed!
            // Likely dead jobs
            {
              type: this.pluginId, // indexed
              status: "INPROGRESS-RETRYABLE", // indexed
              attemptNumber: {$lt: this.MAX_RETRIES}, // indexed
              statusUpdatedAt: {$lte: moment().subtract(this.DEAD_THRESHOLD_MIN, 'minutes').toDate()}, // Indexed!
            },
          ],
        },
      });
      if (claimableJobs.length === 0) {
        this.logger.debug(`No CloudJobs to claim`)
        return
      }
      this.logger.info(`Claiming ${claimableJobs.length} CloudJobs`);
      await this.db.CloudJob.update( // Bulk update
        {
          foremanId: this.foremanId,
          status: "INPROGRESS-RETRYABLE",
          claimedAt: new Date(),
          statusUpdatedAt: new Date(),
        },
        {
          transaction: t,
          where: {id: {$in: claimableJobs.map(j => j.id)}}, // Indexed!
        }
      );
    })
    return claimableJobs
  }

  async cleanupDeadJobs() {
    await this.db.sequelize.transaction(async (t) => {
      const deadJobs = await this.db.CloudJob.findAll({
        transaction: t,
        where: {
          type: this.pluginId,
          status: {$ne: "FAILED"},
          attemptNumber: {$gte: this.MAX_RETRIES}, // Indexed
        }},
      );

      if (deadJobs.length === 0) {
        this.logger.debug(`No dead CloudJobs to cleanup`)
        return
      }
      const e = new Error("Job failed too many times")
      await this.db.CloudJob.update( // Bulk update!
        {
          status: "FAILED",
          error: {message: e.message, stack: e.stack, name: e.constructor.name},
          statusUpdatedAt: new Date(),
        },
        {
          transaction: t,
          where: {id: {$in: deadJobs.map(j => j.id)}}, // Indexed!
        }
      );
      this.logger.info(`Cleaned up ${deadJobs.length} dead jobs`)
    })
  }

  async currentJobLimit(transaction) {
    const inProgress = await this.asyncNumInProgress(transaction);
    this.logger.debug(`${inProgress} CloudJobs in progress`);
    return Math.max((this.MAX_JOBS_PER_FOREMAN - inProgress), 0);
  }

  async asyncNumInProgress(transaction) {
    return this.db.CloudJob.count({
      transaction: transaction,
      where: {
        foremanId: this.foremanId, // Indexed!
        $or: [
          {status: "INPROGRESS-RETRYABLE"}, // Indexed!
          {status: "INPROGRESS-NOTRETRYABLE"},
        ],
      },
    })
  }
}
