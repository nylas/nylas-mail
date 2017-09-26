const cidRegexString = 'src=[\'"]cid:([^\'"]*)[\'"]';
const cidRegex = new RegExp(cidRegexString, 'g');

export default { cidRegexString, cidRegex };
