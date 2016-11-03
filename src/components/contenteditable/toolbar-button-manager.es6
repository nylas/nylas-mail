import { DOMUtils, ContenteditableExtension } from 'nylas-exports';
import ToolbarButtons from './toolbar-buttons';

// This contains the logic to declaratively render the core
// <ToolbarButtons> component in a <FloatingToolbar>
export default class ToolbarButtonManager extends ContenteditableExtension {

  // See the {EmphasisFormattingExtension} and {LinkManager} and other
  // extensions for toolbarButtons.
  static toolbarButtons() { return []; }

  static toolbarComponentConfig({toolbarState}) {
    if (toolbarState.dragging || toolbarState.doubleDown) { return null; }
    if (!toolbarState.selectionSnapshot) { return null; }
    if (toolbarState.selectionSnapshot.isCollapsed) { return null; }

    const locationRef = DOMUtils.getRangeInScope(toolbarState.editableNode);
    if (!locationRef) { return null; }

    const buttonConfigs = this._toolbarButtonConfigs(toolbarState);
    const range = DOMUtils.getRangeInScope(toolbarState.editableNode);
    if (!range || !range.startContainer) {
      return null;
    }

    let locationRefNode = null;
    if (range.startContainer.nodeType === Node.ELEMENT_NODE) {
      locationRefNode = range.startContainer.childNodes[range.startOffset];
    }
    if (!locationRefNode) {
      locationRefNode = range;
    }

    return {
      locationRefNode: locationRefNode,
      component: ToolbarButtons,
      width: buttonConfigs.length * 28.5,
      height: 34,
      props: {
        buttonConfigs,
      },
    };
  }

  static _toolbarButtonConfigs(toolbarState) {
    const {extensions, atomicEdit} = toolbarState;
    let buttonConfigs = [];

    for (const extension of extensions) {
      try {
        const extensionConfigs = (extension.toolbarButtons ? extension.toolbarButtons({toolbarState}) : null) || [];
        extensionConfigs.map((config) => {
          const innerClick = config.onClick || (() => {});
          config.onClick = (event) => atomicEdit(innerClick, {event});
          return config;
        });
        buttonConfigs = buttonConfigs.concat(extensionConfigs);
      } catch (error) {
        NylasEnv.reportError(error);
      }
    }

    return buttonConfigs;
  }
}
