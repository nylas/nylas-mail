import {
  Actions,
  ComposerExtension,
} from 'nylas-exports'

export default class ImageUploadComposerExtension extends ComposerExtension {

  static editingActions() {
    return [{
      action: Actions.insertAttachmentIntoDraft,
      callback: ImageUploadComposerExtension._onInsertAttachmentIntoDraft,
    }, {
      action: Actions.removeAttachment,
      callback: ImageUploadComposerExtension._onRemovedAttachment,
    }]
  }

  static _onRemovedAttachment({editor, actionArg}) {
    const upload = actionArg;
    const el = editor.rootNode.querySelector(`.inline-container-${upload.id}`)
    if (el) {
      el.parentNode.removeChild(el);
    }
  }

  static _onInsertAttachmentIntoDraft({editor, actionArg}) {
    if (editor.draftClientId === actionArg.draftClientId) { return }

    editor.insertCustomComponent("InlineImageUploadContainer", {
      className: `inline-container-${actionArg.uploadId}`,
      uploadId: actionArg.uploadId,
    })
  }
}
