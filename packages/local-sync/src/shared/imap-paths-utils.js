function formatImapPath(pathStr) {
  if (!pathStr) {
    throw new Error("Can not format an empty path!");
  }

  const s = pathStr.replace(/^\[Gmail\]\//, '');
  return s;
}

module.exports = {formatImapPath}
