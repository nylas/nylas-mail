import React, {Component, PropTypes} from 'react';
import {ContenteditableExtension, ExtensionRegistry, DOMUtils} from 'nylas-exports';
import {ScrollRegion, Contenteditable} from 'nylas-component-kit';

/**
 * Renders the text editor for the composer
 * Any component registering in the ComponentRegistry with the role
 * 'Composer:Editor' will receive these set of props.
 *
 * In order for the Composer to work correctly and have a complete set of
 * functionality (like file pasting), any registered editor *must* call the
 * provided callbacks at the appropriate time.
 *
 * @param {object} props - props for ComposerEditor
 * @param {string} props.body - Html string with the draft content to be
 * rendered by the editor
 * @param {string} props.draftClientId - Id of the draft being currently edited
 * @param {object} props.initialSelectionSnapshot - Initial content selection
 * that was previously saved
 * @param {object} props.parentActions - Object containg helper actions
 * associated with the parent container
 * @param {props.parentActions.getComposerBoundingRect} props.parentActions.getComposerBoundingRect
 * @param {props.parentActions.scrollTo} props.parentActions.scrollTo
 * @param {props.onFocus} props.onFocus
 * @param {props.onFilePaste} props.onFilePaste
 * @param {props.onBodyChanged} props.onBodyChanged
 * @class ComposerEditor
 */

class ComposerEditor extends Component {
  static displayName = 'ComposerEditor';

  /**
   * This function will return the {DOMRect} for the parent component
   * @function
   * @name props.parentActions.getComposerBoundingRect
   */
  /**
   * This function will make the screen scrollTo the desired position in the
   * message list
   * @function
   * @name props.parentActions.scrollTo
   * @param {object} options
   * @param {string} options.clientId - Id of the message we want to scroll to
   * @param {string} [options.positon] - If clientId is provided, this optional
   * parameter will indicate what position of the message to scrollTo. See
   * {ScrollRegion}
   * @param {DOMRect} options.rect - Bounding rect we want to scroll to
   */
  /**
   * This function should be called when the editing region is focused by the user
   * @callback props.onFocus
   */
  /**
   * This function should be called when the user pastes a file into the editing
   * region
   * @callback props.onFilePaste
   */
  /**
   * This function should be called when the body of the draft changes, i.e.
   * when the editor is being typed into. It should pass in an object that looks
   * like a DOM Event with the current value of the content.
   * @callback props.onBodyChanged
   * @param {object} event - DOMEvent-like object that contains information
   * about the current value of the body
   * @param {string} event.target.value - HTML string that represents the
   * current content of the editor body
   */
  static propTypes = {
    body: PropTypes.string.isRequired,
    draftClientId: PropTypes.string,
    initialSelectionSnapshot: PropTypes.object,
    onFocus: PropTypes.func,
    onBlur: PropTypes.func,
    onFilePaste: PropTypes.func,
    onBodyChanged: PropTypes.func,
    parentActions: PropTypes.shape({
      scrollTo: PropTypes.func,
      getComposerBoundingRect: PropTypes.func,
    }),
  };

  constructor(props) {
    super(props);
    this.state = {
      extensions: ExtensionRegistry.Composer.extensions(),
    };

    class ComposerFocusManager extends ContenteditableExtension {
      static onFocus() {
        if (props.onFocus) {
          return props.onFocus();
        }
      }
      static onBlur() {
        if (props.onBlur) {
          return props.onBlur();
        }
      }
    }

    this._coreExtension = ComposerFocusManager;
  }

  componentDidMount() {
    this.unsub = ExtensionRegistry.Composer.listen(this._onExtensionsChanged);
  }

  componentWillUnmount() {
    this.unsub();
  }


  // Public methods

  /**
   * @private
   * Methods in ES6 classes should be defined using object method shorthand
   * syntax (https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Method_definitions),
   * as opposed to arrow function syntax, if we want them to be enumerated
   * on the prototype. Arrow function syntax is used to lexically bind the `this`
   * value, and are specialized for non-method callbacks, where them picking up
   * the this of their surrounding method or constructor is an advantage.
   * See https://goo.gl/9ZMOGl for an example
   * and http://www.2ality.com/2015/02/es6-classes-final.html for more info.
   */

  // TODO Get rid of these selection methods
  getCurrentSelection() {
    return this.refs.contenteditable.getCurrentSelection();
  }

  getPreviousSelection() {
    return this.refs.contenteditable.getPreviousSelection();
  }

  focus() {
    // focus the composer and place the insertion point at the last text node of
    // the body. Be sure to choose the last node /above/ the signature and any
    // quoted text that is visible. (as in forwarded messages.)
    //
    this.refs.contenteditable.atomicEdit( ({editor})=> {
      editor.rootNode.focus();
      const lastNode = this._findLastNodeBeforeQuoteOrSignature(editor)
      this._selectEndOfNode(lastNode)
    });
  }

  _findLastNodeBeforeQuoteOrSignature(editor) {
    const walker = document.createTreeWalker(editor.rootNode, NodeFilter.SHOW_TEXT);
    const nodesBelowUserBody = editor.rootNode.querySelectorAll('signature, .gmail_quote, blockquote');

    let lastNode = null;
    let node = walker.nextNode();

    while (node != null) {
      let belowUserBody = false;
      for (let i = 0; i < nodesBelowUserBody.length; ++i) {
        if (nodesBelowUserBody[i].contains(node)) {
          belowUserBody = true;
          break;
        }
      }
      if (belowUserBody) {
        break;
      }
      lastNode = node;
      node = walker.nextNode();
    }
    return lastNode
  }

  _findAbsoluteLastNode(editor) {
    const walker = document.createTreeWalker(editor.rootNode, NodeFilter.SHOW_TEXT);
    let lastNode = null;
    let node = walker.nextNode();
    while (node) {
      lastNode = node;
      node = walker.nextNode();
    }
    return lastNode;
  }

  _selectEndOfNode(node) {
    if (node) {
      const range = document.createRange();
      range.selectNodeContents(node);
      range.collapse(false);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
    }
  }

  focusAbsoluteEnd() {
    this.refs.contenteditable.atomicEdit( ({editor})=> {
      editor.rootNode.focus();
      const lastNode = this._findAbsoluteLastNode(editor)
      this._selectEndOfNode(lastNode)
    });
  }

  /**
   * @private
   * This method was included so that the tests don't break
   * TODO refactor the tests!
   */
  _onDOMMutated(mutations) {
    this.refs.contenteditable._onDOMMutated(mutations);
  }


  // Helpers

  _scrollToBottom = ()=> {
    this.props.parentActions.scrollTo({
      clientId: this.props.draftClientId,
      position: ScrollRegion.ScrollPosition.Bottom,
    });
  };

  /**
   * @private
   * If the bottom of the container we're scrolling to is really far away
   * from the contenteditable and your scroll position, we don't want to
   * jump away. This can commonly happen if the composer has a very tall
   * image attachment. The "send" button may be 1000px away from the bottom
   * of the contenteditable. props.parentActions.scrollToBottom moves to the bottom of
   * the "send" button.
   */
  _bottomIsNearby = (editableNode)=> {
    const parentRect = this.props.parentActions.getComposerBoundingRect();
    const selfRect = editableNode.getBoundingClientRect();
    return Math.abs(parentRect.bottom - selfRect.bottom) <= 250;
  };

  /**
   * @private
   * As you're typing a lot of content and the cursor begins to scroll off
   * to the bottom, we want to make it look like we're tracking your
   * typing.
   */
  _shouldScrollToBottom(selection, editableNode) {
    return (
      this.props.parentActions.scrollTo != null &&
      DOMUtils.atEndOfContent(selection, editableNode) &&
      this._bottomIsNearby(editableNode)
    );
  }

  /**
   * @private
   * When the selectionState gets set (e.g. undo-ing and
   * redo-ing) we need to make sure it's visible to the user.
   *
   * Unfortunately, we can't use the native `scrollIntoView` because it
   * naively scrolls the whole window and doesn't know not to scroll if
   * it's already in view. There's a new native method called
   * `scrollIntoViewIfNeeded`, but this only works when the scroll
   * container is a direct parent of the requested element. In this case
   * the scroll container may be many levels up.
  */
  _ensureSelectionVisible = (selection, editableNode)=> {
    // If our parent supports scroll, check for that
    if (this._shouldScrollToBottom(selection, editableNode)) {
      this._scrollToBottom();
    } else if (this.props.parentActions.scrollTo != null) {
      // Don't bother computing client rects if no scroll method has been provided
      const rangeInScope = DOMUtils.getRangeInScope(editableNode);
      if (!rangeInScope) return;

      let rect = rangeInScope.getBoundingClientRect();
      if (DOMUtils.isEmptyBoundingRect(rect)) {
        rect = DOMUtils.getSelectionRectFromDOM(selection);
      }
      if (rect) {
        this.props.parentActions.scrollTo({rect});
      }
    }
  };


  // Handlers

  _onExtensionsChanged = ()=> {
    this.setState({extensions: ExtensionRegistry.Composer.extensions()});
  };


  // Renderers

  render() {
    return (
      <Contenteditable
        ref="contenteditable"
        value={this.props.body}
        onChange={this.props.onBodyChanged}
        onFilePaste={this.props.onFilePaste}
        onSelectionRestored={this._ensureSelectionVisible}
        initialSelectionSnapshot={this.props.initialSelectionSnapshot}
        extensions={[this._coreExtension].concat(this.state.extensions)} />
    );
  }

}

export default ComposerEditor;
