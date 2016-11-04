/* eslint react/no-danger: 0 */
import React from 'react';
import ReactDOM from 'react-dom';
import _ from 'underscore';

import {Actions, WorkspaceStore, DOMUtils} from 'nylas-exports';
import NylasStore from 'nylas-store';

const TipsBackgroundEl = document.createElement('tutorial-tip-background');

const TipsContainerEl = document.createElement('div');
TipsContainerEl.classList.add('tooltips-container');
document.body.appendChild(TipsContainerEl);


class TipsStoreCls extends NylasStore {
  constructor() {
    super();

    this._tipKeys = [];
  }

  isTipVisible(key) {
    const seen = NylasEnv.config.get('core.tutorial.seen') || [];
    return this._tipKeys.find(t => !seen.includes(t)) === key;
  }

  hasSeenTip(key) {
    return (NylasEnv.config.get('core.tutorial.seen') || []).includes(key);
  }

  // Actions: Since this is a private store just inside this file, we call
  // these methods directly for now.

  mountedTip = (key) => {
    if (!this._tipKeys.includes(key)) {
      this._tipKeys.push(key);
    }
    this.trigger();
  }

  seenTip = (key) => {
    this._tipKeys = this._tipKeys.filter(t => t !== key);
    NylasEnv.config.pushAtKeyPath('core.tutorial.seen', key);
    this.trigger();
  }

  unmountedTip = (key) => {
    this._tipKeys = this._tipKeys.filter(t => t !== key);
    this.trigger();
  }
}

const TipsStore = new TipsStoreCls();

class TipPopoverContents extends React.Component {
  static propTypes = {
    title: React.PropTypes.string,
    tipKey: React.PropTypes.string,
    instructions: React.PropTypes.oneOfType([React.PropTypes.string, React.PropTypes.element]),
    onDismissed: React.PropTypes.func,
  }

  componentDidMount() {
    if (TipsBackgroundEl.parentNode === null) {
      document.body.appendChild(TipsBackgroundEl);
    }
    window.requestAnimationFrame(() => {
      TipsBackgroundEl.classList.add('visible');
    });
  }

  componentWillUnmount() {
    TipsBackgroundEl.classList.remove('visible');
    if (this.props.onDismissed) {
      this.props.onDismissed();
    }
  }

  onDone = () => {
    TipsStore.seenTip(this.props.tipKey);
    Actions.closePopover();
  }

  render() {
    let content = null;

    if (typeof this.props.instructions === 'string') {
      content = <p dangerouslySetInnerHTML={{__html: this.props.instructions}} />;
    } else {
      content = <p>{this.props.instructions}</p>
    }

    return (
      <div style={{width: 250, padding: 20, paddingTop: 0}}>
        <h2>{this.props.title}</h2>
        {content}
        <button className="btn" onClick={this.onDone}>Got it!</button>
      </div>
    );
  }
}

export default function HasTutorialTip(ComposedComponent, TipConfig) {
  const TipKey = ComposedComponent.displayName;

  if (!TipKey) {
    throw new Error("To use the HasTutorialTip decorator, your component must have a displayName.");
  }
  if (TipsStore.hasSeenTip(TipKey)) {
    return ComposedComponent;
  }

  return class extends React.Component {
    static displayName = ComposedComponent.displayName;
    static containerRequired = ComposedComponent.containerRequired;
    static containerStyles = ComposedComponent.containerStyles;

    constructor(props) {
      super(props);
      this._unlisteners = [];
      this.state = {visible: false};
    }

    componentDidMount() {
      TipsStore.mountedTip(TipKey);

      this._unlisteners = [
        TipsStore.listen(this._onTooltipStateChanged),
        WorkspaceStore.listen(() => {
          this._workspaceTimer = setTimeout(this._onTooltipStateChanged, 0);
        }),
      ]
      this._disposables = [
        NylasEnv.themes.onDidChangeActiveThemes(() => {
          this._themesTimer = setTimeout(this._onRecomputeTooltipPosition, 0);
        }),
      ]
      window.addEventListener('resize', this._onRecomputeTooltipPosition);

      // unfortunately, we can't render() a container around ComposedComponent
      // without modifying the DOM tree and messing with things like flexbox.
      // Instead, we leave render() unchanged and attach the bubble and hover
      // listeners to the DOM manually.
      const el = ReactDOM.findDOMNode(this);

      this.tipNode = document.createElement('div');
      this.tipNode.classList.add('tutorial-tip');

      this.tipAnchor = el.closest('[data-tooltips-anchor]') || document.body;
      this.tipAnchor.querySelector('.tooltips-container').appendChild(this.tipNode);

      el.addEventListener('mouseover', this._onMouseOver);
      this._onTooltipStateChanged();
    }

    componentDidUpdate() {
      if (this.state.visible) {
        this._onRecomputeTooltipPosition();
      }
    }

    componentWillUnmount() {
      this._unlisteners.forEach((unlisten) => unlisten())
      this._disposables.forEach((disposable) => disposable.dispose())

      window.removeEventListener('resize', this._onRecomputeTooltipPosition);
      this.tipNode.parentNode.removeChild(this.tipNode);
      clearTimeout(this._workspaceTimer);
      clearTimeout(this._themesTimer);

      TipsStore.unmountedTip(TipKey);
    }

    _containingSheetIsVisible = (el) => {
      const sheetEl = el.closest('.sheet') || el.closest('.sheet-toolbar-container');
      if (!sheetEl) {
        return true;
      }
      return (sheetEl.dataset.id === WorkspaceStore.topSheet().id);
    }

    _isVisible = () => {
      const el = ReactDOM.findDOMNode(this);
      return (
        TipsStore.isTipVisible(TipKey) &&
        this._containingSheetIsVisible(el) &&
        DOMUtils.nodeIsVisible(el)
      )
    }

    _onTooltipStateChanged = () => {
      const visible = this._isVisible()
      if (this.state.visible !== visible) {
        this.setState({visible});
        if (visible) {
          this.tipNode.classList.add('visible');
          this._onRecomputeTooltipPosition();
        } else {
          this.tipNode.classList.remove('visible');
        }
      }
    }

    _onMouseOver = () => {
      if (!this.state.visible) {
        return;
      }

      const el = ReactDOM.findDOMNode(this);
      el.removeEventListener('mouseover', this._onMouseOver);

      const tipRect = this.tipNode.getBoundingClientRect();
      const tipFocusCircleRadius = 64;
      const rect = ReactDOM.findDOMNode(this).getBoundingClientRect();
      const rectCX = Math.round(rect.left + rect.width / 2 - tipFocusCircleRadius);
      const rectCY = Math.round(rect.top + rect.height / 2 - tipFocusCircleRadius);
      TipsBackgroundEl.style.webkitMaskPosition = `0 0, ${rectCX}px ${rectCY}px`;

      Actions.openPopover((
        <TipPopoverContents
          tipKey={TipKey}
          title={TipConfig.title}
          instructions={TipConfig.instructions}
          onDismissed={() => {
            el.addEventListener('mouseover', this._onMouseOver);
          }}
        />
      ), {
        originRect: tipRect,
        direction: 'down',
        fallbackDirection: 'up',
      })
    }

    _onRecomputeTooltipPosition = () => {
      const el = ReactDOM.findDOMNode(this);
      let settled = 0;
      let last = {};
      const attempt = () => {
        const {left, top} = el.getBoundingClientRect();
        const anchorRect = this.tipAnchor.getBoundingClientRect();

        this.tipNode.style.left = `${left - anchorRect.left + 5}px`;
        this.tipNode.style.top = `${Math.max(top - anchorRect.top + 5, 10)}px`;

        if (!_.isEqual(last, {left, top})) {
          settled = 0;
          last = {left, top};
        }
        settled += 1;
        if (settled < 5) {
          window.requestAnimationFrame(attempt);
        }
      }
      attempt();
    }

    render() {
      return (
        <ComposedComponent {...this.props} />
      );
    }
  }
}
