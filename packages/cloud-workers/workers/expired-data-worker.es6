import {Errors} from 'isomorphic-core'

export default class ExpiredDataWorker {
  constructor(cloudJob, {db, logger}) {
    this.job = cloudJob
    this.db = db
    this.logger = logger.child({
      jobId: cloudJob.id,
      contextClass: this.constructor.name,
      contextType: "Worker",
    }); // Should be a child of Foreman's logger
  }

  async run() {
    this.logger.info(`Running ${this.constructor.name}. Initial status: ${this.job.status}. Attempt number: ${this.job.attemptNumber}`)

    await this.db.sequelize.transaction(async (t) => {
      const job = await this.db.CloudJob.findById(this.job.id, {transaction: t});
      job.status = "INPROGRESS-RETRYABLE";
      job.statusUpdatedAt = new Date();
      const attemptNum = job.attemptNumber;
      job.attemptNumber = attemptNum + 1; // beware magic setter method
      await job.save({transaction: t})
    })

    const metadatum = await this.db.Metadata.findById(this.job.metadataId);
    try {
      await this.performAction(metadatum);
      await this.db.CloudJob.update(
        {status: "SUCCEEDED", statusUpdatedAt: new Date()},
        {where: {id: this.job.id}}
      );
      this.logger.info(`${this.constructor.name} Succeeded`)
    } catch (err) {
      await this.db.sequelize.transaction(async (t) => {
        const job = await this.db.CloudJob.findById(this.job.id, {transaction: t});
        job.error = {
          message: err.message,
          name: err.constructor.name,
          stack: err.stack,
        }
        if (err instanceof Errors.RetryableError) {
          job.status = "FAILED-RETRYABLE"
        } else {
          job.status = "FAILED"
        }
        job.statusUpdatedAt = new Date()
        await job.save({transaction: t});
        this.logger.error(err, `${this.constructor.name} Errored`)
      })
    }
  }

  pluginId() {
    throw new Error("You should override this!");
  }

  async performAction() {
    throw new Error("You should override this!");
  }
}
