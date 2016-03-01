import {DOMUtils, ContenteditableExtension} from 'nylas-exports';

export default class TemplateEditor extends ContenteditableExtension {

  static onContentChanged = ({editor})=> {
    // Run through and remove all code nodes that are invalid
    const codeNodes = editor.rootNode.querySelectorAll("code.var.empty");
    for (let ii = 0; ii < codeNodes.length; ii++) {
      const codeNode = codeNodes[ii];

      // remove any style that was added by contenteditable
      codeNode.removeAttribute("style");

      // grab the text content and the indexable text content
      const codeNodeText = codeNode.textContent;
      const indexText = DOMUtils.getIndexedTextContent(codeNode).map(({text})=> text).join("");

      // unwrap any code nodes that don't start/end with {{}}, and any with line breaks inside
      if ((!codeNodeText.startsWith("{{")) || (!codeNodeText.endsWith("}}")) || (indexText.indexOf("\n") > -1)) {
        editor.whilePreservingSelection(()=> {
          DOMUtils.unwrapNode(codeNode);
        });
      }
    }

    // Attempt to sanitize extra nodes that may have been created by contenteditable on certain text editing
    // operations (insertion/deletion of line breaks, etc.). These are generally <span>, but can also be
    // <font>, <b>, and possibly others. The extra nodes often grab CSS styles from neighboring elements
    // as inline style, including the yellow text from <code> nodes that we insert. This is contenteditable
    // trying to be "smart" and preserve styles, which is very undesirable for the <code> node styles. The
    // below code is a hack to prevent yellow text from appearing.
    const starNodes = editor.rootNode.querySelectorAll("*");
    for (let ii = 0; ii < starNodes.length; ii++) {
      const node = starNodes[ii];
      if ((!node.className) && (node.style.color === "#c79b11")) {
        editor.whilePreservingSelection(()=> {
          DOMUtils.unwrapNode(node);
        });
      }
    }

    const fontNodes = editor.rootNode.querySelectorAll("font");
    for (let ii = 0; ii < fontNodes.length; ii++) {
      const node = fontNodes[ii];
      if (node.color === "#c79b11") {
        editor.whilePreservingSelection(()=> {
          DOMUtils.unwrapNode(node);
        });
      }
    }

    // Find all {{}} and wrap them in code nodes if they aren't already
    // Regex finds any {{ <contents> }} that doesn't contain {, }, or \n
    // https://regex101.com/r/jF2oF4/1
    for (const range of editor.regExpSelectorAll(/\{\{[^\n{}]*?\}\}/g)) {
      if (!DOMUtils.isWrapped(range, "CODE")) {
        // Preserve the selection based on text index within the range matched by the regex
        const selIndex = editor.getSelectionTextIndex(range);
        const codeNode = DOMUtils.wrap(range, "CODE");
        codeNode.className = "var empty";

        // Sets node contents to just its textContent, strips HTML
        codeNode.textContent = codeNode.textContent;

        if (selIndex !== undefined) {
          editor.restoreSelectionByTextIndex(codeNode, selIndex.startIndex, selIndex.endIndex);
        }
      }
    }
  }
}

module.exports = TemplateEditor
