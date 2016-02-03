import {DOMUtils, ContenteditableExtension} from 'nylas-exports'
import EmojiActions from './emoji-actions'
import EmojiPicker from './emoji-picker'
const emoji = require('node-emoji');
const emojis = Object.keys(emoji.emoji).sort();

class EmojisComposerExtension extends ContenteditableExtension {

  static onContentChanged = ({editor, mutations}) => {
    sel = editor.currentSelection()
    let {emojiOptions, triggerWord} = EmojisComposerExtension._findEmojiOptions(sel);
    if (sel.anchorNode && sel.isCollapsed) {
      let {emojiOptions, triggerWord} = EmojisComposerExtension._findEmojiOptions(sel);
      if (emojiOptions.length > 0) {
        offset = sel.anchorOffset;
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
      }
      else {
        if (DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete")) {
          editor.unwrapNodeAndSelectAll(DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete"));
          editor.select(sel.anchorNode,
                        sel.anchorOffset + triggerWord.length,
                        sel.focusNode,
                        sel.focusOffset + triggerWord.length);
        }
      }
    }
    else {
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
    sel = toolbarState.selectionSnapshot;
    if (sel) {
      let {emojiOptions, triggerWord} = EmojisComposerExtension._findEmojiOptions(sel);
      if (emojiOptions.length > 0 && !toolbarState.dragging && !toolbarState.doubleDown) {
        locationRefNode = DOMUtils.closest(toolbarState.selectionSnapshot.anchorNode,
                                           "n1-emoji-autocomplete");
        emojiNameNode = DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete");
        selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
        return {
          component: EmojiPicker,
          props: {emojiOptions,
                  selectedEmoji},
          locationRefNode: locationRefNode,
          width: EmojisComposerExtension._emojiPickerWidth(emojiOptions)
        }
      }
    }
    return null;
  }

  static editingActions = () => {
    return [{
      action: EmojiActions.selectEmoji,
      callback: EmojisComposerExtension._onSelectEmoji
    }]
  }

  static onKeyDown = ({editor, event}) => {
    sel = editor.currentSelection()
    let {emojiOptions, triggerWord} = EmojisComposerExtension._findEmojiOptions(sel);
    if (emojiOptions.length > 0) {
      if (event.key == "ArrowDown" || event.key == "ArrowRight" ||
          event.key == "ArrowUp" || event.key == "ArrowLeft") {
        event.preventDefault();
        moveToNext = (event.key == "ArrowDown" || event.key == "ArrowRight")
        emojiNameNode = DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete");
        selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
        if (selectedEmoji) {
          emojiIndex = emojiOptions.indexOf(selectedEmoji);
          if (emojiIndex < emojiOptions.length - 1 && moveToNext) {
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[emojiIndex + 1]);
          }
          else if (emojiIndex > 0 && !moveToNext) {
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[emojiIndex - 1]);
          }
          else {
            index = moveToNext ? 0 : emojiOptions.length - 1;
            emojiNameNode.setAttribute("selectedEmoji", emojiOptions[index]);
          }
        }
        else {
          index = moveToNext ? 1 : emojiOptions.length - 1;
          emojiNameNode.setAttribute("selectedEmoji", emojiOptions[index]);
        }
      }
      else if (event.key == "Enter") {
        event.preventDefault();
        emojiNameNode = DOMUtils.closest(sel.anchorNode, "n1-emoji-autocomplete");
        selectedEmoji = emojiNameNode.getAttribute("selectedEmoji");
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
      words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset).split(" ");
      lastWord = words[words.length - 1];
      if (words.length == 1 &&
          lastWord.indexOf(" ") == -1 &&
          lastWord.indexOf(":") == -1) {
        let {text, textNode} = EmojisComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
        lastWord = text;
      }
      if (lastWord.length > 1 &&
          lastWord.charAt(0) == ":" &
          lastWord.charAt(lastWord.length - 1) != " ") {
        let word = lastWord.substring(1).trim();
        if (lastWord.charAt(lastWord.length - 1) == ":") {
          word = word.substring(0, word.length - 1);
        }
        return {triggerWord: lastWord, emojiOptions: EmojisComposerExtension._findMatches(word)};
      }
      return {triggerWord: lastWord, emojiOptions: []};
    }
    return {triggerWord: "", emojiOptions: []};
  }

  static _onSelectEmoji = ({editor, actionArg}) => {
    emojiChar = actionArg.emojiChar;
    if (!emojiChar) return null;
    sel = editor.currentSelection()
    if (sel.anchorNode &&
        sel.anchorNode.nodeValue &&
        sel.anchorNode.nodeValue.length > 0 &&
        sel.isCollapsed) {
      words = sel.anchorNode.nodeValue.substring(0, sel.anchorOffset).split(" ");
      lastWord = words[words.length - 1];
      if (words.length == 1 &&
          lastWord.indexOf(" ") == -1 &&
          lastWord.indexOf(":") == -1) {
          let {text, textNode} = EmojisComposerExtension._getTextUntilSpace(sel.anchorNode, sel.anchorOffset);
          lastWord = text;
          offset = textNode.nodeValue.lastIndexOf(":");
          editor.select(textNode,
                        offset,
                        sel.focusNode,
                        sel.focusOffset);
      }
      else {
        editor.select(sel.anchorNode,
                      sel.anchorOffset - lastWord.length,
                      sel.focusNode,
                      sel.focusOffset);
      }
      editor.insertText(emojiChar);
    }
  }

  static _emojiPickerWidth(emojiOptions) {
    let max_length = 0;
    for (emojiOption of emojiOptions) {
      if (emojiOption.length > max_length) {
        max_length = emojiOption.length;
      }
    }
    WIDTH_PER_CHAR = 8;
    return (max_length + 10) * WIDTH_PER_CHAR;
  }

  static _getTextUntilSpace(node, offset) {
    text = node.nodeValue.substring(0, offset);
    prevTextNode = DOMUtils.previousTextNode(node);
    if (!prevTextNode) return {text: text, textNode: node};
    while (prevTextNode) {
      if (prevTextNode.nodeValue.indexOf(" ") == -1 &&
          prevTextNode.nodeValue.indexOf(":") == -1) {
        text = prevTextNode.nodeValue + text;
        prevTextNode = DOMUtils.previousTextNode(prevTextNode);
      }
      else {
        break;
      }
    }
    text = prevTextNode.nodeValue.trim() + text;
    return {text: text, textNode: prevTextNode};
  }

  static _findMatches(word) {
    emojiOptions = []
    for (const curEmoji of emojis) {
      if (word == curEmoji.substring(0, word.length)) {
        emojiOptions.push(curEmoji);
      }
    }
    return emojiOptions;
  }

}

export default EmojisComposerExtension;
