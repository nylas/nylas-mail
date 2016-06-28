module.exports = {
  order: 2,
  processMessage: ({message}) => Promise.resolve(message),
}
