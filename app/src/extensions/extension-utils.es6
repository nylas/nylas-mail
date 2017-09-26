import RegExpUtils from '../regexp-utils';

export function getFunctionArgs(func) {
  const match = func.toString().match(RegExpUtils.functionArgs());
  if (!match) return [[]];
  const matchStr = match[1] || match[2];
  return matchStr.split(/\s*,\s*/);
}
