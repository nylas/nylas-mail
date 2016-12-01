const Joi = require('joi');

function replacer(key, value) {
  // force remove any disallowed keys here
  return value;
}

function jsonSchema(modelName) {
  const models = ['Message', 'Thread', 'File', 'Error', 'SyncbackRequest', 'Account', 'Contact']

  if (models.includes(modelName)) {
    return Joi.object();
  }
  if (modelName === 'Error') {
    return Joi.object().keys({
      message: Joi.string(),
      type: Joi.string(),
    })
  }
  if (modelName === 'Account') {
    // Ben: Disabled temporarily because folks keep changing the keys and it's hard
    // to keep in sync. Might need to consider another approach to these.
    // return Joi.object().keys({
    //   id: Joi.number(),
    //   object: Joi.string(),
    //   email_address: Joi.string(),
    //   provider: Joi.string(),
    //   organization_unit: Joi.string(),
    //   connection_settings: Joi.object(),
    //   sync_policy: Joi.object(),
    //   sync_error: Joi.object().allow(null),
    //   first_sync_completion: Joi.number().allow(null),
    //   last_sync_completions: Joi.array(),
    // })
  }
  if (modelName === 'Folder') {
    return Joi.object().keys({
      id: Joi.string(),
      object: Joi.string(),
      account_id: Joi.string(),
      name: Joi.string().allow(null),
      display_name: Joi.string(),
    })
  }
  if (modelName === 'Label') {
    return Joi.object().keys({
      id: Joi.string(),
      object: Joi.string(),
      account_id: Joi.string(),
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
