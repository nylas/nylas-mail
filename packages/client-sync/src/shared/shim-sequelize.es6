const _ = require('underscore');

const DEFAULT_SEQUELIZE_SHIM_TIMEOUT = 60 * 1000; // 1 min

const shimObject = (obj) => {
  Object.keys(obj).forEach(key => {
    // Skip internal methods.
    if (key.startsWith('_')) {
      return;
    }

    const prop = obj[key];
    // Only patch methods.
    if (!_.isFunction(prop)) {
      return;
    }

    obj[key] = function(...args) {  // eslint-disable-line
      const result = prop.call(this, ...args);
      if (result && _.isFunction(result.then)) {
        return new Promise(async (resolve, reject) => {
          try {
            resolve(await result);
          } catch (err) {
            reject(err);
          }
        }).timeout(DEFAULT_SEQUELIZE_SHIM_TIMEOUT, `${key} timed out`);
      }
      return result;
    };
  });
};

export default function shimSequelize(Sequelize) {
  shimObject(Sequelize.Model);
  shimObject(Sequelize.Instance.prototype);
}
