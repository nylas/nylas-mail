import React from 'react';
import ReactDOM from 'react-dom';
import _ from "underscore";
import {EventedIFrame} from 'nylas-component-kit';
import {Utils, QuotedHTMLTransformer} from 'nylas-exports';
import {autolink} from './autolinker';
import {autoscaleImages} from './autoscale-images';
import EmailFrameStylesStore from './email-frame-styles-store';

export default class EmailFrame extends React.Component {
  static displayName = 'EmailFrame';

  static propTypes = {
    content: React.PropTypes.string.isRequired,
    showQuotedText: React.PropTypes.bool,
  };

  componentDidMount() {
    this._mounted = true;
    this._writeContent();
    this._unlisten = EmailFrameStylesStore.listen(this._writeContent);
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (!Utils.isEqualReact(nextProps, this.props) ||
            !Utils.isEqualReact(nextState, this.state));
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
  }

  _writeContent = () => {
    const iframeNode = ReactDOM.findDOMNode(this.refs.iframe);
    const doc = iframeNode.contentDocument;
    if (!doc) { return; }
    doc.open();

    // NOTE: The iframe must have a modern DOCTYPE. The lack of this line
    // will cause some bizzare non-standards compliant rendering with the
    // message bodies. This is particularly felt with <table> elements use
    // the `border-collapse: collapse` css property while setting a
    // `padding`.
    doc.write("<!DOCTYPE html>");
    const styles = EmailFrameStylesStore.styles();
    if (styles) {
      doc.write(`<style>${styles}</style>`);
    }
    doc.write(`<div id='inbox-html-wrapper'>${this._emailContent()}</div>`);
    doc.close();

    autolink(doc, {async: true});
    autoscaleImages(doc);

    // Notify the EventedIFrame that we've replaced it's document (with `open`)
    // so it can attach event listeners again.
    this.refs.iframe.didReplaceDocument();
    this._onMustRecalculateFrameHeight();
  }

  _onMustRecalculateFrameHeight = () => {
    this.refs.iframe.setHeightQuietly(0);
    this._lastComputedHeight = 0;
    this._setFrameHeight();
  }

  _getFrameHeight = (doc) => {
    if (doc && doc.body) {
      return doc.body.scrollHeight;
    }
    if (doc && doc.documentElement) {
      return doc.documentElement.scrollHeight;
    }
    return 0;
  }

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
    const holderNode = ReactDOM.findDOMNode(this.refs.iframeHeightHolder);
    const iframeNode = ReactDOM.findDOMNode(this.refs.iframe);
    const height = this._getFrameHeight(iframeNode.contentDocument);

    // Why 5px? Some emails have elements with a height of 100%, and then put
    // tracking pixels beneath that. In these scenarios, the scrollHeight of the
    // message is always <100% + 1px>, which leads us to resize them constantly.
    // This is a hack, but I'm not sure of a better solution.
    if (Math.abs(height - this._lastComputedHeight) > 5) {
      this.refs.iframe.setHeightQuietly(height);
      holderNode.style.height = `${height}px`;
      this._lastComputedHeight = height;
    }

    if (iframeNode.contentDocument.readyState !== 'complete') {
      _.defer(()=> this._setFrameHeight());
    }
  }

  render() {
    return (
      <div
        className="iframe-container"
        ref="iframeHeightHolder"
        style={{height: this._lastComputedHeight}}>
        <EventedIFrame
          ref="iframe"
          seamless="seamless"
          searchable
          onResize={this._onMustRecalculateFrameHeight}
        />
      </div>
    );
  }
}
