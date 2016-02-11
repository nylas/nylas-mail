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
                        sel.anchorOffset - triggerWord.length,
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
                        sel.anchorOffset + triggerWord.length,
                        sel.focusNode,
                        sel.focusOffset + triggerWord.length);
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
  };

  static toolbarComponentConfig = ({toolbarState}) => {
    const sel = toolbarState.selectionSnapshot;
    if (sel) {
      const {emojiOptions} = EmojisComposerExtension._findEmojiOptions(sel);
      if (emojiOptions.length > 0 && !toolbarState.dragging && !toolbarState.doubleDown) {
        const locationRefNode = DOMUtils.closest(sel.anchorNode,
                                                 "n1-emoji-autocomplete");
        const emojiNameNode = DOMUtils.closest(sel.anchorNode,
                                               "n1-emoji-autocomplete");
        const selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
        return {
          component: EmojiPicker,
          props: {emojiOptions,
                  selectedEmoji},
          locationRefNode: locationRefNode,
          width: EmojisComposerExtension._emojiPickerWidth(emojiOptions),
        }
      }
    }
    return null;
  };

  static editingActions = () => {
    return [{
      action: EmojiActions.selectEmoji,
      callback: EmojisComposerExtension._onSelectEmoji,
    }]
  };

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
  };

  static _findEmojiOptions(sel) {
    if (sel.anchorNode &&
        sel.anchorNode.nodeValue &&
        sel.anchorNode.nodeValue.length > 0 &&
        sel.isCollapsed) {
      const words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset).split(" ");
      let lastWord = words[words.length - 1].trim();
      if (words.length === 1 &&
          lastWord.indexOf(" ") === -1 &&
          lastWord.indexOf(":") === -1) {
        const {text} = EmojisComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
        lastWord = text;
      }
      if (lastWord.length > 1 &&
          lastWord.charAt(0) === ":" &
          lastWord.charAt(lastWord.length - 1) !== " ") {
        let word = lastWord.substring(1);
        if (lastWord.charAt(lastWord.length - 1) === ":") {
          word = word.substring(0, word.length - 1);
        }
        return {triggerWord: lastWord, emojiOptions: EmojisComposerExtension._findMatches(word)};
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
      const words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset).split(" ");
      let lastWord = words[words.length - 1].trim();
      if (words.length === 1 &&
          lastWord.indexOf(" ") === -1 &&
          lastWord.indexOf(":") === -1) {
        const {text, textNode} = EmojisComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
        lastWord = text;
        const offset = textNode.nodeValue.lastIndexOf(":");
        editor.select(textNode,
                      offset,
                      sel.focusNode,
                      sel.focusOffset);
      } else {
        editor.select(sel.anchorNode,
                      sel.anchorOffset - lastWord.length,
                      sel.focusNode,
                      sel.focusOffset);
      }
      editor.insertText(emojiChar);
    }
  };

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
