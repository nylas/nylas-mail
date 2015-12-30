import {getFunctionArgs} from './extension-utils';

export function isUsingOutdatedAPI(func) {
  // Might not always be true, but it is our best guess
  const firstArg = getFunctionArgs(func)[0];
  return (
    firstArg.includes('mes') ||
    firstArg.includes('msg') ||
    firstArg.includes('body') ||
    firstArg.includes('draft')
  );
}

export default function adaptExtension(extension) {
  const original = extension.formatMessageBody;
  if (!original || !isUsingOutdatedAPI(original)) return extension;
  extension.formatMessageBody = ({message})=> {
    original(message);
  };
  return extension;
}
