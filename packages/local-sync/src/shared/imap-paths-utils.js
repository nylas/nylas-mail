function formatImapPath(pathStr) {
  if (!pathStr) {
    throw new Error("Can not format an empty path!");
  }

  // https://regex101.com/r/yeyZJh/1
  const s = pathStr.replace(/^\[Gmail]\//, '');
  return s;
}

module.exports = {formatImapPath}
