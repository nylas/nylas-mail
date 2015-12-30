import RegExpUtils from '../regexp-utils';

export function getFunctionArgs(func) {
  const match = func.toString().match(RegExpUtils.functionArgs());
  if (!match) return null;
  return match[1].split(/\s*,\s*/);
}
