import { Actions, ComposerExtension } from 'mailspring-exports';

export default class InlineImageComposerExtension extends ComposerExtension {
  static editingActions() {
    return [
      {
        action: Actions.insertAttachmentIntoDraft,
        callback: InlineImageComposerExtension._onInsertAttachmentIntoDraft,
      },
      {
        action: Actions.removeAttachment,
        callback: InlineImageComposerExtension._onRemovedAttachment,
      },
    ];
  }

  static _onRemovedAttachment({ editor, actionArg }) {
    const file = actionArg;
    const el = editor.rootNode.querySelector(`.inline-container-${file.id}`);
    if (el) {
      el.parentNode.removeChild(el);
    }
  }

  static _onInsertAttachmentIntoDraft({ editor, actionArg }) {
    if (editor.headerMessageId === actionArg.headerMessageId) {
      return;
    }

    editor.insertCustomComponent('InlineImageUploadContainer', {
      className: `inline-container-${actionArg.fileId}`,
      fileId: actionArg.fileId,
    });
  }
}
