const Rx = require('rx-lite');
const Sequelize = require('sequelize');

Sequelize.Model.prototype.streamAll = function streamAll(options = {}) {
  return Rx.Observable.create((observer) => {
    const chunkSize = options.chunkSize || 1000;
    options.offset = 0;
    options.limit = chunkSize;

    const findFn = (opts) => {
      this.findAll(opts).then((models = []) => {
        observer.onNext(models)
        if (models.length === chunkSize) {
          opts.offset += chunkSize;
          findFn(opts)
        } else {
          observer.onCompleted()
        }
      })
    }

    findFn(options)
  })
}

