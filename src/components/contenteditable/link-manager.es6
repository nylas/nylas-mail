import { RegExpUtils, DOMUtils, ContenteditableExtension } from 'nylas-exports';
import LinkEditor from './link-editor';

export default class LinkManager extends ContenteditableExtension {
  static keyCommandHandlers() {
    return {
      "contenteditable:insert-link": LinkManager._onInsertLink,
    };
  }

  static toolbarButtons() {
    return [{
      className: "btn-link",
      onClick: LinkManager._onInsertLink,
      tooltip: "Edit Link",
      iconUrl: null, // Defined in the css of btn-link
    }];
  }

  // By default, if you're typing next to an existing anchor tag, it won't
  // continue the anchor text. This is important for us since we want you
  // to be able to select and then override the existing anchor text with
  // something new.
  static onContentChanged({editor}) {
    const sel = editor.currentSelection();
    if (sel.anchorNode && sel.isCollapsed) {
      const node = sel.anchorNode;
      const sibling = node.previousSibling;

      if (!sibling) {
        return;
      }
      if (sel.anchorOffset > 1) {
        return;
      }
      if (node.nodeType !== Node.TEXT_NODE) {
        return;
      }
      if (sibling.nodeName !== "A") {
        return;
      }
      if (/^\s+/.test(node.data)) {
        return;
      }
      if (RegExpUtils.punctuation({exclude: ['\\-', '_']}).test(node.data[0])) {
        return;
      }

      if (node.data.length > 1) {
        node.splitText(1);
      }
      sibling.appendChild(node);
      sibling.normalize();
      const text = DOMUtils.findLastTextNode(sibling);
      editor.select(text, text.length, text, text.length);
    }
  }

  static toolbarComponentConfig({toolbarState}) {
    if (toolbarState.dragging || toolbarState.doubleDown) {
      return null;
    }

    let linkToModify = null;
    if (!linkToModify && toolbarState.selectionSnapshot) {
      linkToModify = LinkManager._linkAtCursor(toolbarState);
    }

    if (!linkToModify) {
      return null;
    }

    return {
      component: LinkEditor,
      props: {
        onSaveUrl: (url, link) => {
          toolbarState.atomicEdit(LinkManager._onSaveUrl, {url, linkToModify: link});
        },
        onDoneWithLink: () => {
          toolbarState.atomicEdit(LinkManager._onDoneWithLink)
        },
        linkToModify: linkToModify,
        focusOnMount: LinkManager._shouldFocusOnMount(toolbarState),
      },
      locationRefNode: linkToModify,
      width: LinkManager._linkWidth(linkToModify),
      height: 34,
    };
  }

  static _shouldFocusOnMount(toolbarState) {
    return !toolbarState.selectionSnapshot.isCollapsed;
  }

  static _linkAttributeHref(linkToModify) {
    return ((linkToModify && linkToModify.getAttribute) ? linkToModify.getAttribute('href') : null) || "";
  }

  static _linkWidth(linkToModify) {
    const href = LinkManager._linkAttributeHref(linkToModify);
    const WIDTH_PER_CHAR = 8;
    return Math.max((href.length * WIDTH_PER_CHAR) + 95, 210);
  }

  static _linkAtCursor(toolbarState) {
    if (toolbarState.selectionSnapshot.isCollapsed) {
      const anchor = toolbarState.selectionSnapshot.anchorNode;
      const node = DOMUtils.closest(anchor, 'a, n1-prompt-link');
      const lastTextNode = DOMUtils.findLastTextNode(anchor);
      if (lastTextNode && toolbarState.selectionSnapshot.anchorOffset === lastTextNode.data.length) {
        return null;
      }
      return node;
    }

    const anchor = toolbarState.selectionSnapshot.anchorNode;
    const focus = toolbarState.selectionSnapshot.anchorNode;
    const aPrompt = DOMUtils.closest(anchor, 'n1-prompt-link');
    const fPrompt = DOMUtils.closest(focus, 'n1-prompt-link');
    if (aPrompt && fPrompt && aPrompt === fPrompt) {
      const aTag = DOMUtils.closest(aPrompt, 'a');
      return aTag || aPrompt;
    }
    return null;
  }

  // TODO FIXME: Unfortunately, the keyCommandHandler fires before the
  // Contentedtiable onKeyDown.
  //
  // Normally this wouldn't matter, but when `_onInsertLink` runs it will
  // focus on the input box of the link editor.
  //
  // If onKeyDown in the Contenteditable runs after this, then
  // `atomicUpdate` will reset the selection back to the Contenteditable.
  // This process blurs the link input, which causes the LinkInput to close
  // and attempt to set or clear the link. The net effect is that the link
  // insertion appears to not work via keyboard commands.
  //
  // This would not be a problem if the rendering of the Toolbar happened
  // at the same time as the Contenteditable's render cycle. Unfortunatley
  // since the Contenteditable shouldn't re-render on all Selection
  // changes, while the Toolbar should, these are out of sync.
  //
  // The temporary fix is adding a _.defer block to change the ordering of
  // these keyboard events.
  static _onInsertLink({editor}) {
    setTimeout(() => {
      if (editor.currentSelection().isCollapsed) {
        const html = "<n1-prompt-link>link text</n1-prompt-link>";
        editor.insertHTML(html, {selectInsertion: true});
      } else {
        editor.wrapSelection("n1-prompt-link");
      }
    }, 0);
  }

  static _onDoneWithLink({editor}) {
    for (const node of Array.from(editor.rootNode.querySelectorAll("n1-prompt-link"))) {
      editor.unwrapNodeAndSelectAll(node);
    }
  }

  static _onSaveUrl({editor, url, linkToModify}) {
    let toSelect = null;

    if (linkToModify != null) {
      const equivalentNode = DOMUtils.findSimilarNodeAtIndex(editor.rootNode, linkToModify, 0);
      if (equivalentNode == null) {
        return;
      }
      if (LinkManager._linkAttributeHref(linkToModify).trim() === url.trim()) {
        return;
      }
      toSelect = equivalentNode;
    } else {
      // When atomicEdit gets run, the exportedSelection is already restored to
      // the last saved exportedSelection state. Any operation we perform will
      // apply to the last saved exportedSelection state.
      toSelect = null;
    }

    if (url.trim().length === 0) {
      if (toSelect) {
        editor.select(toSelect).unlink();
      } else {
        editor.unlink();
      }
    } else {
      if (toSelect) {
        editor.select(toSelect).createLink(url);
      } else {
        editor.createLink(url);
      }
    }

    for (const node of Array.from(editor.rootNode.querySelectorAll("n1-prompt-link"))) {
      editor.unwrapNodeAndSelectAll(node);
    }
  }
}
