import {DOMUtils, ContenteditableExtension} from 'nylas-exports'
import EmojiActions from './emoji-actions'
import EmojiPicker from './emoji-picker'
const emoji = require('node-emoji');
const emojis = Object.keys(emoji.emoji).sort();

class EmojisComposerExtension extends ContenteditableExtension {

  static onContentChanged = ({editor}) => {
    const sel = editor.currentSelection()
    const {emojiOptions, triggerWord} = EmojisComposerExtension._findEmojiOptions(sel);
    if (sel.anchorNode && sel.isCollapsed) {
      if (emojiOptions.length > 0) {
        const offset = sel.anchorOffset;
        if (!DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete")) {
          editor.select(sel.anchorNode,
                        sel.anchorOffset - triggerWord.length - 1,
                        sel.focusNode,
                        sel.focusOffset).wrapSelection("n1-emoji-autocomplete");
          editor.select(sel.anchorNode,
                        offset,
                        sel.anchorNode,
                        offset);
        }
      } else {
        if (DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete")) {
          editor.unwrapNodeAndSelectAll(DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete"));
          editor.select(sel.anchorNode,
                        sel.anchorOffset + triggerWord.length + 1,
                        sel.focusNode,
                        sel.focusOffset + triggerWord.length + 1);
        }
      }
    } else {
      if (DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete")) {
        editor.unwrapNodeAndSelectAll(DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete"));
        editor.select(sel.anchorNode,
                      sel.anchorOffset + triggerWord.length,
                      sel.focusNode,
                      sel.focusOffset + triggerWord.length);
      }
    }
  }

  static toolbarComponentConfig = ({toolbarState}) => {
    const sel = toolbarState.selectionSnapshot;
    if (sel) {
      const {emojiOptions} = EmojisComposerExtension._findEmojiOptions(sel);
      if (emojiOptions.length > 0 && !toolbarState.dragging && !toolbarState.doubleDown) {
        const locationRefNode = DOMUtils.closest(sel.anchorNode,
                                                 "n1-emoji-autocomplete");
        if (!locationRefNode) return null;
        const selectedEmoji = locationRefNode.getAttribute("selectedEmoji");
        return {
          component: EmojiPicker,
          props: {emojiOptions,
                  selectedEmoji},
          locationRefNode: locationRefNode,
          width: EmojisComposerExtension._emojiPickerWidth(emojiOptions),
          height: EmojisComposerExtension._emojiPickerHeight(emojiOptions),
        }
      }
    }
    return null;
  }

  static editingActions = () => {
    return [{
      action: EmojiActions.selectEmoji,
      callback: EmojisComposerExtension._onSelectEmoji,
    }]
  }

  static onKeyDown = ({editor, event}) => {
    const sel = editor.currentSelection()
    const {emojiOptions} = EmojisComposerExtension._findEmojiOptions(sel);
    if (emojiOptions.length > 0) {
      if (event.key === "ArrowDown" || event.key === "ArrowRight" ||
          event.key === "ArrowUp" || event.key === "ArrowLeft") {
        event.preventDefault();
        const moveToNext = (event.key === "ArrowDown" || event.key === "ArrowRight")
        const emojiNameNode = DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete");
        const selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
        if (selectedEmoji) {
          const emojiIndex = emojiOptions.indexOf(selectedEmoji);
          if (emojiIndex < emojiOptions.length - 1 && moveToNext) {
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[emojiIndex + 1]);
          } else if (emojiIndex > 0 && !moveToNext) {
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[emojiIndex - 1]);
          } else {
            const index = moveToNext ? 0 : emojiOptions.length - 1;
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[index]);
          }
        } else {
          const index = moveToNext ? 1 : emojiOptions.length - 1;
          emojiNameNode.setAttribute("selectedEmoji", emojiOptions[index]);
        }
      } else if (event.key === "Enter") {
        event.preventDefault();
        const emojiNameNode = DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete");
        let selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
        if (!selectedEmoji) selectedEmoji = emojiOptions[0];
        EmojisComposerExtension._onSelectEmoji({editor: editor,
                                                actionArg: {emojiChar: emoji.get(selectedEmoji)}});
      }
    }
  }

  static _findEmojiOptions(sel) {
    if (sel.anchorNode &&
        sel.anchorNode.nodeValue &&
        sel.anchorNode.nodeValue.length > 0 &&
        sel.isCollapsed) {
      const words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset);
      let index = words.lastIndexOf(":");
      let lastWord = "";
      if (index !== -1 && words.lastIndexOf(" ") < index) {
        lastWord = words.substring(index + 1, sel.anchorOffset);
      } else {
        const {text} = EmojisComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
        index = text.lastIndexOf(":");
        if (index !== -1 && text.lastIndexOf(" ") < index) {
          lastWord = text.substring(index + 1);
        } else {
          return {triggerWord: "", emojiOptions: []};
        }
      }
      if (lastWord.length > 0) {
        return {triggerWord: lastWord, emojiOptions: EmojisComposerExtension._findMatches(lastWord)};
      }
      return {triggerWord: lastWord, emojiOptions: []};
    }
    return {triggerWord: "", emojiOptions: []};
  }

  static _onSelectEmoji = ({editor, actionArg}) => {
    const emojiChar = actionArg.emojiChar;
    if (!emojiChar) return null;
    const sel = editor.currentSelection()
    if (sel.anchorNode &&
        sel.anchorNode.nodeValue &&
        sel.anchorNode.nodeValue.length > 0 &&
          sel.isCollapsed) {
      const words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset);
      let index = words.lastIndexOf(":");
      let lastWord = words.substring(index + 1, sel.anchorOffset);
      if (index !== -1 && words.lastIndexOf(" ") < index) {
        editor.select(sel.anchorNode,
                      sel.anchorOffset - lastWord.length - 1,
                      sel.focusNode,
                      sel.focusOffset);
      } else {
        const {text, textNode} = EmojisComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
        index = text.lastIndexOf(":");
        lastWord = text.substring(index + 1);
        const offset = textNode.nodeValue.lastIndexOf(":");
        editor.select(textNode,
                      offset,
                      sel.focusNode,
                      sel.focusOffset);
      }
      editor.insertText(emojiChar);
    }
  }

  static _emojiPickerWidth(emojiOptions) {
    let maxLength = 0;
    for (const emojiOption of emojiOptions) {
      if (emojiOption.length > maxLength) {
        maxLength = emojiOption.length;
      }
    }
    const WIDTH_PER_CHAR = 8;
    return (maxLength + 10) * WIDTH_PER_CHAR;
  }

  static _emojiPickerHeight(emojiOptions) {
    const HEIGHT_PER_EMOJI = 28;
    if (emojiOptions.length < 5) {
      return emojiOptions.length * HEIGHT_PER_EMOJI + 20;
    }
    return 5 * HEIGHT_PER_EMOJI + 20;
  }

  static _getTextUntilSpace(node, offset) {
    let text = node.nodeValue.substring(0, offset);
    let prevTextNode = DOMUtils.previousTextNode(node);
    if (!prevTextNode) return {text: text, textNode: node};
    while (prevTextNode) {
      if (prevTextNode.nodeValue.indexOf(" ") === -1 &&
          prevTextNode.nodeValue.indexOf(":") === -1) {
        text = prevTextNode.nodeValue + text;
        prevTextNode = DOMUtils.previousTextNode(prevTextNode);
      } else {
        text = prevTextNode.nodeValue.trim() + text;
        break;
      }
    }
    return {text: text, textNode: prevTextNode};
  }

  static _findMatches(word) {
    const emojiOptions = []
    for (const curEmoji of emojis) {
      if (word === curEmoji.substring(0, word.length)) {
        emojiOptions.push(curEmoji);
      }
    }
    return emojiOptions;
  }

}

export default EmojisComposerExtension;
