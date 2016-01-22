module.exports =
class MessageUtils
  @cidRegexString: "src=['\"]cid:([^'\"]*)['\"]"
  @cidRegex: new RegExp(@cidRegexString, "g")
