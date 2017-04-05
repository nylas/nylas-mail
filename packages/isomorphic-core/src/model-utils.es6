import _ from 'underscore'

function deepClone(object, customizer, stackSeen = [], stackRefs = []) {
  let newObject;
  if (!_.isObject(object)) { return object; }
  if (_.isFunction(object)) { return object; }

  if (_.isArray(object)) {
    // http://perfectionkills.com/how-ecmascript-5-still-does-not-allow-to-subclass-an-array/
    newObject = [];
  } else if (object instanceof Date) {
    // You can't clone dates by iterating through `getOwnPropertyNames`
    // of the Date object. We need to special-case Dates.
    newObject = new Date(object);
  } else {
    newObject = Object.create(Object.getPrototypeOf(object));
  }

  // Circular reference check
  const seenIndex = stackSeen.indexOf(object);
  if (seenIndex >= 0) { return stackRefs[seenIndex]; }
  stackSeen.push(object); stackRefs.push(newObject);

  // It's important to use getOwnPropertyNames instead of Object.keys to
  // get the non-enumerable items as well.
  for (const key of Array.from(Object.getOwnPropertyNames(object))) {
    const newVal = deepClone(object[key], customizer, stackSeen, stackRefs);
    if (_.isFunction(customizer)) {
      newObject[key] = customizer(key, newVal);
    } else {
      newObject[key] = newVal;
    }
  }
  return newObject;
}

function copyModel(Model, model, updates = {}) {
  const fields = Object.keys(model.dataValues)
  const data = {}
  for (const field of fields) {
  // We can't just copy over the values directly from `dataValues` because
  // they are the raw values, and we would ignore custom getters.
  // Rather, we access them from the model instance.
  // For example our JSON database type, is simply a string and the custom
  // getter parses it into json. We want to get the parsed json, not the
  // string
    data[field] = model[field]
  }
  return Model.build(Object.assign({}, data, updates))
}

function isValidId(value) {
  if (value == null) { return false; }
  if (isNaN(parseInt(value, 36))) {
    return false
  }
  return true
}

export default {
  deepClone,
  copyModel,
  isValidId,
}
