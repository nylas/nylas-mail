/* eslint react/prefer-stateless-function: 0 */
/* eslint global-require: 0 */
import React from 'react'
import ReactDOM from 'react-dom'
import {remote} from 'electron'
import _str from 'underscore.string'
import {
  Actions,
  ComponentRegistry,
  WorkspaceStore,
} from "nylas-exports";

import Flexbox from './components/flexbox'
import RetinaImg from './components/retina-img'
import Utils from './flux/models/utils'

let Category = null;
let FocusedPerspectiveStore = null;

class ToolbarSpacer extends React.Component {
  static displayName = 'ToolbarSpacer';
  static propTypes = {
    order: React.PropTypes.number,
  };

  render() {
    return (
      <div className="item-spacer" style={{flex: 1, order: this.props.order || 0}} />
    );
  }
}

class WindowTitle extends React.Component {
  static displayName = "WindowTitle";

  constructor(props) {
    super(props);
    this.state = NylasEnv.getLoadSettings();
  }

  componentDidMount() {
    this.disposable = NylasEnv.onWindowPropsReceived(() =>
      this.setState(NylasEnv.getLoadSettings())
    );
  }

  componentWillUnmount() {
    if (this.disposable) {
      this.disposable.dispose();
    }
  }

  render() {
    return (
      <div className="window-title">{this.state.title}</div>
    );
  }
}

class ToolbarBack extends React.Component {
  static displayName = 'ToolbarBack';

  // These stores are only required when this Toolbar is actually needed.
  // This is because loading these stores has database side effects.
  constructor(props) {
    super(props);
    Category = Category || require('./flux/models/category').default
    FocusedPerspectiveStore = FocusedPerspectiveStore || require('./flux/stores/focused-perspective-store').default
    this.state = {
      categoryName: FocusedPerspectiveStore.current().name,
    }
  }

  componentDidMount() {
    this._unsubscriber = FocusedPerspectiveStore.listen(() =>
      this.setState({categoryName: FocusedPerspectiveStore.current().name})
    );
  }

  componentWillUnmount() {
    if (this._unsubscriber) {
      this._unsubscriber();
    }
  }

  _onClick = () => {
    Actions.popSheet();
  }

  render() {
    let title = "Back";
    if (this.state.categoryName === Category.AllMailName) {
      title = 'All Mail'
    } else if (this.state.categoryName) {
      title = _str.titleize(this.state.categoryName);
    }
    return (
      <div className="item-back" onClick={this._onClick} title={`Return to ${title}`}>
        <RetinaImg name="sheet-back.png" mode={RetinaImg.Mode.ContentIsMask} />
        <div className="item-back-title">{title}</div>
      </div>
    );
  }
}

class ToolbarWindowControls extends React.Component {
  static displayName = 'ToolbarWindowControls';

  constructor(props) {
    super(props);
    this.state = {alt: false};
  }

  componentDidMount() {
    if (process.platform === 'darwin') {
      window.addEventListener('keydown', this._onAlt);
      window.addEventListener('keyup', this._onAlt);
    }
  }

  componentWillUnmount() {
    if (process.platform === 'darwin') {
      window.removeEventListener('keydown', this._onAlt);
      window.removeEventListener('keyup', this._onAlt);
    }
  }

  _onAlt = (event) => {
    if (this.state.alt !== event.altKey) {
      this.setState({alt: event.altKey});
    }
  }

  _onMaximize = (event) => {
    if (process.platform === 'darwin' && !event.altKey) {
      NylasEnv.setFullScreen(!NylasEnv.isFullScreen());
    } else {
      NylasEnv.maximize();
    }
  }

  render() {
    return (
      <div name="ToolbarWindowControls" className={`toolbar-window-controls alt-${this.state.alt}`}>
        <button tabIndex={-1} className="close" onClick={() => NylasEnv.close()} />
        <button tabIndex={-1} className="minimize" onClick={() => NylasEnv.minimize()} />
        <button tabIndex={-1} className="maximize" onClick={this._onMaximize} />
      </div>
    );
  }
}

class ToolbarMenuControl extends React.Component {
  static displayName = 'ToolbarMenuControl';

  _onOpenMenu = () => {
    const {applicationMenu} = remote.getGlobal('application');
    applicationMenu.menu.popup(NylasEnv.getCurrentWindow());
  }

  render() {
    return (
      <div className="toolbar-menu-control">
        <button tabIndex={-1} className="btn btn-toolbar" onClick={this._onOpenMenu}>
          <RetinaImg name="windows-menu-icon.png" mode={RetinaImg.Mode.ContentIsMask} />
        </button>
      </div>
    );
  }
}

ComponentRegistry.register(ToolbarWindowControls, {
  location: WorkspaceStore.Sheet.Global.Toolbar.Left,
});

ComponentRegistry.register(ToolbarMenuControl, {
  location: WorkspaceStore.Sheet.Global.Toolbar.Right,
});

export default class Toolbar extends React.Component {
  static displayName= 'Toolbar';

  static propTypes = {
    data: React.PropTypes.object,
    depth: React.PropTypes.number,
  }

  static childContextTypes = {
    sheetDepth: React.PropTypes.number,
  }

  constructor(props) {
    super(props);
    this.state = this._getStateFromStores();
  }

  getChildContext() {
    return {
      sheetDepth: this.props.depth,
    }
  }

  componentDidMount() {
    this.mounted = true
    this.unlisteners = []
    this.unlisteners.push(WorkspaceStore.listen(() =>
      this.setState(this._getStateFromStores())
    ));
    this.unlisteners.push(ComponentRegistry.listen(() =>
      this.setState(this._getStateFromStores())
    ));
    window.addEventListener("resize", this._onWindowResize)
    window.requestAnimationFrame(() => this.recomputeLayout());
  }

  componentWillReceiveProps(props) {
    this.setState(this._getStateFromStores(props));
  }

  shouldComponentUpdate(nextProps, nextState) {
    // This is very important. Because toolbar uses ReactCSSTransitionGroup,
    // repetitive unnecessary updates can break animations and cause performance issues.
    return !Utils.isEqualReact(nextProps, this.props) || !Utils.isEqualReact(nextState, this.state);
  }

  componentDidUpdate() {
    // Wait for other components that are dirty (the actual columns in the sheet)
    window.requestAnimationFrame(() => this.recomputeLayout());
  }

  componentWillUnmount() {
    this.mounted = false
    window.removeEventListener("resize", this._onWindowResize);
    for (const u of this.unlisteners) {
      u();
    }
  }

  recomputeLayout() {
    // Yes this really happens - do not remove!
    if (!this.mounted) {
      return;
    }

    // Find our item containers that are tied to specific columns
    const el = ReactDOM.findDOMNode(this);
    const columnToolbarEls = el.querySelectorAll('[data-column]');

    // Find the top sheet in the stack
    const sheet = document.querySelectorAll("[name='Sheet']")[this.props.depth];
    if (!sheet) {
      return;
    }

    // Position item containers so they have the position and width
    // as their respective columns in the top sheet
    for (const columnToolbarEl of columnToolbarEls) {
      const column = columnToolbarEl.dataset.column;
      const columnEl = sheet.querySelector(`[data-column='${column}']`);
      if (!columnEl) {
        continue;
      }

      columnToolbarEl.style.display = 'inherit'
      columnToolbarEl.style.left = `${columnEl.offsetLeft}px`
      columnToolbarEl.style.width = `${columnEl.offsetWidth}px`;
    }

    // Record our overall height for sheets
    remote.getCurrentWindow().setSheetOffset(el.clientHeight);
  }

  _onWindowResize = () => {
    this.recomputeLayout();
  }

  _getStateFromStores(props = this.props) {
    const state = {
      mode: WorkspaceStore.layoutMode(),
      columns: [],
      columnNames: [],
    }

    // Add items registered to Regions in the current sheet
    if (props.data && props.data.columns[state.mode]) {
      for (const loc of props.data.columns[state.mode]) {
        if (WorkspaceStore.isLocationHidden(loc)) {
          continue;
        }
        const entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar, mode: state.mode});
        state.columns.push(entries);
        if (entries) {
          state.columnNames.push(loc.Toolbar.id.split(":")[0]);
        }
      }
    }

    // Add left items registered to the Sheet instead of to a Region
    if (state.columns.length > 0) {
      for (const loc of [WorkspaceStore.Sheet.Global, props.data]) {
        const entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar.Left, mode: state.mode})
        state.columns[0].push(...entries);
      }
      if (props.depth > 0) {
        state.columns[0].push(ToolbarBack);
      }

      // Add right items registered to the Sheet instead of to a Region
      for (const loc of [WorkspaceStore.Sheet.Global, props.data]) {
        const entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar.Right, mode: state.mode})
        state.columns[state.columns.length - 1].push(...entries);
      }

      if (state.mode === "popout") {
        state.columns[0].push(WindowTitle);
      }
    }

    return state;
  }

  _flexboxForComponents(components) {
    const elements = components.map((Component) =>
      <Component key={Component.displayName} {...this.props} />
    );
    return (
      <Flexbox className="item-container" direction="row">
        {elements}
        <ToolbarSpacer key="spacer-50" order={-50} />
        <ToolbarSpacer key="spacer+50" order={50} />
      </Flexbox>
    );
  }

  render() {
    const style = {
      position: 'absolute',
      width: '100%',
      height: '100%',
      zIndex: 1,
    };

    const toolbars = this.state.columns.map((components, idx) =>
      <div
        style={{position: 'absolute', top: 0, display: 'none'}}
        className={`toolbar-${this.state.columnNames[idx]}`}
        data-column={idx}
        key={idx}
      >
        {this._flexboxForComponents(components)}
      </div>
    );

    return (
      <div
        style={style}
        className={`sheet-toolbar-container mode-${this.state.mode}`}
        data-id={this.props.data.id}
      >
        {toolbars}
      </div>
    );
  }
}
