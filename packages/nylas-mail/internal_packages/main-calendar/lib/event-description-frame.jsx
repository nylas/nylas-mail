import React from 'react';
import ReactDOM from 'react-dom';
import {EventedIFrame} from 'nylas-component-kit';
import {Utils} from 'nylas-exports';

export default class EmailFrame extends React.Component {
  static displayName = 'EmailFrame';

  static propTypes = {
    content: React.PropTypes.string.isRequired,
  };

  componentDidMount() {
    this._mounted = true;
    this._writeContent();
  }

  shouldComponentUpdate(nextProps, nextState) {
    return (!Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state));
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
    doc.write(`<div id='inbox-html-wrapper'>${this.props.content}</div>`);
    doc.close();

    // autolink(doc, {async: true});
    // autoscaleImages(doc);
    // addInlineDownloadPrompts(doc);

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
    let height = 0;

    if (doc && doc.body) {
      // Why reset the height? body.scrollHeight will always be 0 if the height
      // of the body is dependent on the iframe height e.g. if height ===
      // 100% in inline styles or an email stylesheet
      const style = window.getComputedStyle(doc.body)
      if (style.height === '0px') {
        doc.body.style.height = "auto"
      }
      height = doc.body.scrollHeight;
    }

    if (doc && doc.documentElement) {
      height = doc.documentElement.scrollHeight;
    }

    // scrollHeight does not include space required by scrollbar
    return height + 25;
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
      setTimeout(() => this._setFrameHeight(), 0);
    }
  }

  render() {
    return (
      <div
        className="iframe-container"
        ref="iframeHeightHolder"
        style={{height: this._lastComputedHeight}}
      >
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
