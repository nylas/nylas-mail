module.exports = {
  copyModel(Model, model, updates = {}) {
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
  },

  isValidId(value) {
    if (value == null) { return false; }
    if (isNaN(parseInt(value, 36))) {
      return false
    }
    return true
  },
}
