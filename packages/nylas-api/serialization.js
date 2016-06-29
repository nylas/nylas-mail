const Joi = require('joi');

function replacer(key, value) {
  // force remove any disallowed keys here
  return value;
}

function jsonSchema(modelName) {
  const models = ['Message', 'Thread', 'File', 'Error', 'SyncbackRequest']
  if (models.includes(modelName)) {
    return Joi.object();
  }
  if (modelName === 'Account') {
    return Joi.object().keys({
      id: Joi.number(),
      email_address: Joi.string(),
      connection_settings: Joi.object(),
      sync_policy: Joi.object(),
      sync_error: Joi.object(),
    })
  }
  if (modelName === 'Category') {
    return Joi.object().keys({
      id: Joi.number(),
      name: Joi.string().allow(null),
      display_name: Joi.string(),
    })
  }
  return null;
}

function jsonStringify(models) {
  return JSON.stringify(models, replacer, 2);
}

module.exports = {
  jsonSchema,
  jsonStringify,
}
