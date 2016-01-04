import _ from 'underscore';
import DOMUtils from '../dom-utils';
import {deprecate} from '../deprecate-utils';
import {getFunctionArgs} from './extension-utils';

export function isUsingOutdatedContenteditableApi(func) {
  // Might not always be true, but it is our best guess
  const firstArg = getFunctionArgs(func)[0];
  if (func.length > 1) return true;  // Not using a named arguments hash
  return (
    firstArg.includes('ev') ||
    firstArg.includes('node') ||
    firstArg.includes('Node')
  );
}

export function isUsingOutdatedComposerApi(func) {
  const firstArg = getFunctionArgs(func)[0];
  return (
    firstArg.includes('dr') ||
    firstArg.includes('sess') ||
    firstArg.includes('prox')
  );
}

export function adaptComposerMethod(extension, method) {
  const original = extension[method];
  if (!original || !isUsingOutdatedComposerApi(original)) return;

  if (method === 'finalizeSessionBeforeSending') {
    extension[method] = (argsObj)=> {
      return original(argsObj.session);
    };
  } else {
    extension[method] = (argsObj)=> {
      return original(argsObj.draft);
    };
  }
}

export function adaptContenteditableMethod(extension, method, original = extension[method]) {
  // Check if it is using old API
  if (!original || !isUsingOutdatedContenteditableApi(original)) return;

  let deprecatedArgs = '';
  extension[method] = (argsObj)=> {
    const {editor, event, mutations} = argsObj;
    const eventOrMutations = event || mutations || {};
    const extraArgs = _.keys(_.omit(argsObj, ['editor', 'event', 'mutations'])).map(
      key => argsObj[key]
    );

    // This is our best guess at the function signature that is being used
    const firstArg = getFunctionArgs(original)[0];
    if (firstArg.includes('editor')) {
      deprecatedArgs = '(editor, ...)';
      original(editor, eventOrMutations, ...extraArgs);
    } else if (firstArg.includes('ev')) {
      deprecatedArgs = '(event, editableNode, selection, ...)';
      original(eventOrMutations, editor.rootNode, editor.currentSelection(), ...extraArgs);
    } else {
      deprecatedArgs = '(editableNode, selection, ...)';
      original(editor.rootNode, editor.currentSelection(), eventOrMutations, ...extraArgs);
    }
  };

  extension[method] = deprecate(
    `ComposerExtension.${method}${deprecatedArgs}`,
    `ComposerExtension.${method}(args = {editor, ...})`,
    extension,
    extension[method]
  );
}

export function adaptOnInput(extension) {
  if (extension.onContentChanged != null) return;
  adaptContenteditableMethod(extension, 'onContentChanged', extension.onInput);
}

export function adaptOnTabDown(extension) {
  if (!extension.onTabDown) return;
  const origOnKeyDown = extension.onKeyDown;
  extension.onKeyDown = ({editor, event})=> {
    if (event.key === 'Tab') {
      const range = DOMUtils.getRangeInScope(editor.rootNode);
      extension.onTabDown(editor.rootNode, range, event);
    } else {
      // At this point, onKeyDown should have already been adapted
      if (origOnKeyDown != null) origOnKeyDown(editor, event);
    }
  };

  extension.onKeyDown = deprecate(
    'DraftStoreExtension.onTabDown',
    'ComposerExtension.onKeyDown',
    extension,
    extension.onKeyDown
  );
}

export function adaptOnMouseUp(extension) {
  if (!extension.onMouseUp) return;
  const origOnClick = extension.onClick;
  extension.onClick = ({editor, event})=> {
    const range = DOMUtils.getRangeInScope(editor.rootNode);
    extension.onMouseUp(editor.rootNode, range, event);
    // At this point, onClick should have already been adapted
    if (origOnClick != null) origOnClick(editor, event);
  };

  extension.onClick = deprecate(
    'DraftStoreExtension.onMouseUp',
    'ComposerExtension.onClick',
    extension,
    extension.onClick
  );
}

export default function adaptExtension(extension) {
  const contenteditableMethods = [
    'onContentChanged',
    'onBlur',
    'onFocus',
    'onClick',
    'onKeyDown',
    'onShowContextMenu',
  ];
  contenteditableMethods.forEach(
    method => adaptContenteditableMethod(extension, method)
  );

  // Special contenteditable cases
  adaptOnInput(extension);
  adaptOnTabDown(extension);
  adaptOnMouseUp(extension);


  const composerMethods = [
    'warningsForSending',
    'prepareNewDraft',
    'finalizeSessionBeforeSending',
  ];
  composerMethods.forEach(
    method => adaptComposerMethod(extension, method)
  );

  return extension;
}
