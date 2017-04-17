import {ContenteditableExtension} from 'nylas-exports';

// This provides the default baisc formatting options for the
// Contenteditable using the declarative extension API.
//
// NOTE: Blockquotes get their own formatting in `BlockquoteManager`
export default class ParagraphFormattingExtension extends ContenteditableExtension {
  static keyCommandHandlers() {
    return {
      "contenteditable:indent": this._onIndent,
      "contenteditable:outdent": this._onOutdent,
    };
  }

  static toolbarButtons() {
    return [];
  }

  static _onIndent({editor}) {
    editor.indent();
  }

  static _onOutdent({editor}) {
    editor.outdent();
  }

  // None of the paragraph formatting buttons need a custom component.
  //
  // They use the default <ToolbarButtons> component via the
  // `toolbarButtons` extension API.
  //
  // We can either return `null` or return the requsted object with no
  // component.
  static toolbarComponentConfig() {
    return null;
  }
}
