
function jsonError(error) {
  return {
    message: error.message,
    stack: error.stack ? error.stack.split('\n') : [],
  }
}

module.exports = {
  jsonError,
}
