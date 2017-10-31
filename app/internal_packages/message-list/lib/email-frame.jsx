import _ from 'underscore';
import { EventedIFrame } from 'mailspring-component-kit';
import {
  React,
  ReactDOM,
  PropTypes,
  Utils,
  QuotedHTMLTransformer,
  MessageStore,
} from 'mailspring-exports';
import { autolink } from './autolinker';
import { adjustImages } from './adjust-images';
import { addInlineImageListeners } from './inline-image-listeners';
import EmailFrameStylesStore from './email-frame-styles-store';

export default class EmailFrame extends React.Component {
  static displayName = 'EmailFrame';

  static propTypes = {
    content: PropTypes.string.isRequired,
    message: PropTypes.object,
    showQuotedText: PropTypes.bool,
  };

  componentDidMount() {
    this._mounted = true;
    this._writeContent();
    this._unlisten = EmailFrameStylesStore.listen(this._writeContent);
  }

  shouldComponentUpdate(nextProps, nextState) {
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  componentDidUpdate() {
    this._writeContent();
  }

  componentWillUnmount() {
    this._mounted = false;
    if (this._unlisten) {
      this._unlisten();
    }
  }

  _emailContent = () => {
    // When showing quoted text, always return the pure content
    if (this.props.showQuotedText) {
      return this.props.content;
    }
    return QuotedHTMLTransformer.removeQuotedHTML(this.props.content, {
      keepIfWholeBodyIsQuote: true,
    });
  };

  _writeContent = () => {
    const iframeNode = ReactDOM.findDOMNode(this._iframeComponent);
    const doc = iframeNode.contentDocument;
    if (!doc) {
      return;
    }
    doc.open();

    // NOTE: The iframe must have a modern DOCTYPE. The lack of this line
    // will cause some bizzare non-standards compliant rendering with the
    // message bodies. This is particularly felt with <table> elements use
    // the `border-collapse: collapse` css property while setting a
    // `padding`.
    doc.write('<!DOCTYPE html>');
    const styles = EmailFrameStylesStore.styles();
    if (styles) {
      doc.write(`<style>${styles}</style>`);
    }
    doc.write(
      `<div id='inbox-html-wrapper' class="${process.platform}">${this._emailContent()}</div>`
    );
    doc.close();

    autolink(doc, { async: true });
    adjustImages(doc);
    addInlineImageListeners(doc);

    for (const extension of MessageStore.extensions()) {
      if (!extension.renderedMessageBodyIntoDocument) {
        continue;
      }
      try {
        extension.renderedMessageBodyIntoDocument({
          document: doc,
          message: this.props.message,
          iframe: iframeNode,
        });
      } catch (e) {
        AppEnv.reportError(e);
      }
    }

    // Notify the EventedIFrame that we've replaced it's document (with `open`)
    // so it can attach event listeners again.
    this._iframeComponent.didReplaceDocument();
    this._onMustRecalculateFrameHeight();
  };

  _onMustRecalculateFrameHeight = () => {
    this._iframeComponent.setHeightQuietly(0);
    this._lastComputedHeight = 0;
    this._setFrameHeight();
  };

  _getFrameHeight = doc => {
    let height = 0;

    // If documentElement has a scroll height, prioritize that as height
    // If not, fall back to body scroll height by setting it to auto
    if (doc && doc.documentElement && doc.documentElement.scrollHeight > 0) {
      height = doc.documentElement.scrollHeight;
    } else if (doc && doc.body) {
      const style = window.getComputedStyle(doc.body);
      if (style.height === '0px') {
        doc.body.style.height = 'auto';
      }
      height = doc.body.scrollHeight;
    }

    // scrollHeight does not include space required by scrollbar
    return height + 25;
  };

  _setFrameHeight = () => {
    if (!this._mounted) {
      return;
    }

    // Q: What's up with this holder?
    // A: If you resize the window, or do something to trigger setFrameHeight
    // on an already-loaded message view, all the heights go to zero for a brief
    // second while the heights are recomputed. This causes the ScrollRegion to
    // reset it's scrollTop to ~0 (the new combined heiht of all children).
    // To prevent this, the holderNode holds the last computed height until
    // the new height is computed.
    const iframeNode = ReactDOM.findDOMNode(this._iframeComponent);
    const height = this._getFrameHeight(iframeNode.contentDocument);

    // Why 5px? Some emails have elements with a height of 100%, and then put
    // tracking pixels beneath that. In these scenarios, the scrollHeight of the
    // message is always <100% + 1px>, which leads us to resize them constantly.
    // This is a hack, but I'm not sure of a better solution.
    if (Math.abs(height - this._lastComputedHeight) > 5) {
      this._iframeComponent.setHeightQuietly(height);
      this._iframeHeightHolderEl.style.height = `${height}px`;
      this._lastComputedHeight = height;
    }

    if (iframeNode.contentDocument.readyState !== 'complete') {
      _.defer(() => this._setFrameHeight());
    }
  };

  render() {
    return (
      <div
        className="iframe-container"
        ref={el => {
          this._iframeHeightHolderEl = el;
        }}
        style={{ height: this._lastComputedHeight }}
      >
        <EventedIFrame
          ref={cm => {
            this._iframeComponent = cm;
          }}
          seamless="seamless"
          searchable
          onResize={this._onMustRecalculateFrameHeight}
        />
      </div>
    );
  }
}
