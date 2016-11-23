const Joi = require('joi');

function replacer(key, value) {
  // force remove any disallowed keys here
  return value;
}

function jsonSchema(modelName) {
  const models = ['Metadata']

  if (models.includes(modelName)) {
    return Joi.object();
  }
  if (modelName === 'Error') {
    return Joi.object().keys({
      message: Joi.string(),
      type: Joi.string(),
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
