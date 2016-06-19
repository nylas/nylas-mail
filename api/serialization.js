const Joi = require('joi');

function replacer(key, value) {
  // force remove any disallowed keys here
  return value;
}

function jsonSchema(modelName) {
  if (modelName === 'Account') {
    return Joi.object().keys({
      id: Joi.number(),
      email_address: Joi.string(),
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
