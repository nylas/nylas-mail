import React from 'react';
import ReactDOM from 'react-dom';

import {Flexbox,
 ConfigPropContainer,
 ScrollRegion,
 KeyCommandsRegion} from 'nylas-component-kit';
import {PreferencesUIStore} from 'nylas-exports';


import PreferencesTabsBar from './preferences-tabs-bar';

class PreferencesRoot extends React.Component {

  static displayName = 'PreferencesRoot';

  constructor() {
    super();
    this.state = this.getStateFromStores();
  }

  componentDidMount() {
    ReactDOM.findDOMNode(this).focus();
    this.unlisteners = [];
    this.unlisteners.push(PreferencesUIStore.listen(() =>
      this.setState(this.getStateFromStores(), () => {
        const scrollRegion = document.querySelector(".preferences-content .scroll-region-content");
        scrollRegion.scrollTop = 0;
      })
    ));
    this._focusContent();
  }

  componentDidUpdate() {
    this._focusContent();
  }

  componentWillUnmount() {
    this.unlisteners.forEach(unlisten => unlisten());
  }

  getStateFromStores() {
    const tabs = PreferencesUIStore.tabs();
    const selection = PreferencesUIStore.selection();
    const tabId = selection.get('tabId');
    const tab = tabs.find((s) => s.tabId === tabId);
    return {
      tabs: tabs,
      selection: selection,
      tab: tab,
    }
  }

  static containerRequired = false;

  _localHandlers() {
    const stopPropagation = (e) => {
      e.stopPropagation();
    }
    // This prevents some basic commands from propagating to the threads list and
    // producing unexpected results

    // TODO This is a partial/temporary solution and should go away when we do the
    // Keymap/Commands/Menu refactor
    return {
      'core:next-item': stopPropagation,
      'core:previous-item': stopPropagation,
      'core:select-up': stopPropagation,
      'core:select-down': stopPropagation,
      'core:select-item': stopPropagation,
      'core:messages-page-up': stopPropagation,
      'core:messages-page-down': stopPropagation,
      'core:list-page-up': stopPropagation,
      'core:list-page-down': stopPropagation,
      'application:remove-from-view': stopPropagation,
      'application:gmail-remove-from-view': stopPropagation,
      'application:remove-and-previous': stopPropagation,
      'application:remove-and-next': stopPropagation,
      'application:archive-item': stopPropagation,
      'application:delete-item': stopPropagation,
      'application:print-thread': stopPropagation,
    }
  }

  // Focus the first thing with a tabindex when we update.
  // inside the content area. This makes it way easier to interact with prefs.
  _focusContent() {
    const node = ReactDOM.findDOMNode(this.refs.content).querySelector('[tabindex]')
    if (node) {
      node.focus();
    }
  }

  render() {
    let bodyElement = <div></div>;
    if (this.state.tab) {
      bodyElement = <this.state.tab.component accountId={this.state.selection.get('accountId')} />
    }

    return (
      <KeyCommandsRegion className="preferences-wrap" tabIndex="1" localHandlers={this._localHandlers()}>
        <Flexbox direction="column">
          <PreferencesTabsBar tabs={this.state.tabs}
                              selection={this.state.selection} />
          <ScrollRegion className="preferences-content">
            <ConfigPropContainer ref="content">
              {bodyElement}
            </ConfigPropContainer>
          </ScrollRegion>
        </Flexbox>
      </KeyCommandsRegion>
    );
  }

}

export default PreferencesRoot;
