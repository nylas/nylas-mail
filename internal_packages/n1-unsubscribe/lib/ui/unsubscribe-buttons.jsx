const {React} = require('nylas-exports'); // eslint-disable-line
const {RetinaImg, KeyCommandsRegion} = require('nylas-component-kit'); // eslint-disable-line
const ThreadUnsubscribeStoreManager = require('../thread-unsubscribe-store-manager');
const ThreadConditionType = require(`${__dirname}/../enum/threadConditionType`); // eslint-disable-line

const UNSUBSCRIBE_ASSETS_URL = 'nylas://n1-unsubscribe/assets/';

class ThreadUnsubscribeButton extends React.Component {

  static containerRequired = false;

  constructor(props) {
    super(props);
    this.state = {
      condition: ThreadConditionType.LOADING,
      hasLinks: false,
    };
  }

  componentWillMount() {
    this.load(this.props);
  }

  componentWillReceiveProps(newProps) {
    console.warn(newProps);
    this.load(newProps);
  }

  componentWillUnmount() {
    return this.unload();
  }

  onMessageLoad(threadState) {
    this.setState(threadState);
  }

  onClick(event) {
    if (this && this.tuStore) {
      this.tuStore.unsubscribe();
    } else {
      console.error('ERROR: No tuStore object from within onClick event...??');
    }
    event.stopPropagation()
  }

  getIconInfo(name : string, ratio : number) {
    let url = UNSUBSCRIBE_ASSETS_URL;
    let buttonTitle;
    let extraClasses;
    let scale = ratio

    if (typeof scale === 'undefined') {
      scale = Math.ceil(window.devicePixelRatio);
      if (scale !== 1 || scale !== 2) { scale = 2; }
    }

    url += name;
    switch (this.state.condition) {
      case ThreadConditionType.UNSUBSCRIBED:
        extraClasses = 'unsubscribe-success';
        buttonTitle = 'Unsubscribe (Success!)';
        url += '-success';
        break;
      case ThreadConditionType.ERRORED:
        extraClasses = 'unsubscribe-error';
        buttonTitle = 'Unsubscribe (Error)';
        url += '-error';
        break;
      case ThreadConditionType.DISABLED:
        extraClasses = 'unsubscribe-disabled';
        buttonTitle = 'Unsubscribe (Disabled)';
        url += '';
        break;
      case ThreadConditionType.DONE:
        extraClasses = 'unsubscribe-ready';
        buttonTitle = 'Unsubscribe Now!';
        url += '';
        break;
      default:
        extraClasses = 'unsubscribe-loading';
        buttonTitle = 'Unsubscribe (Loading)';
        url += '-loading';
        break;
    }

    url += `@${scale}x.png`;

    return {buttonTitle, extraClasses, url};
  }

  load(props) {
    this.unload();
    this.tuStore = ThreadUnsubscribeStoreManager.getStoreForThread(props.thread);
    this.unlisten = this.tuStore.listen(this.onMessageLoad.bind(this));
    this.tuStore.triggerUpdate();
  }

  unload() {
    if (this.unlisten) {
      this.unlisten();
    }
    this.unlisten = null;
    this.tuStore = null;
  }

  render() {
    return null;
  }
}

class ThreadUnsubscribeQuickActionButton extends ThreadUnsubscribeButton {

  static displayName = 'ThreadUnsubscribeQuickActionButton';

  render() {
    const {buttonTitle, extraClasses, url} = this.getIconInfo('unsubscribe');
    return (
      <button
        key="unsubscribe"
        title={buttonTitle}
        className={`btn action action-unsubscribe ${extraClasses}`}
        style={{
          order: 90,
          background: `url(${url}) center no-repeat`,
        }}
        onClick={this.onClick.bind(this)}
      />
    );
  }
}

class ThreadUnsubscribeToolbarButton extends ThreadUnsubscribeButton {

  static displayName = 'ThreadUnsubscribeToolbarButton';

  _keymapHandlers() {
    return {"n1-unsubscribe:unsubscribe": this._keymapEvent}
  }

  render() {
    const {buttonTitle, extraClasses, url} = this.getIconInfo('toolbar-unsubscribe');
    return (
      <KeyCommandsRegion
        globalHandlers={this._keymapHandlers(this)}
        style={{order: -102}}
      >
        <button
          title={buttonTitle}
          id={'N1-Unsubscribe'}
          className={`btn btn-toolbar toolbar-unsubscribe ${extraClasses}`}
          onClick={this.onClick.bind(this)}
        >
          <RetinaImg
            mode={RetinaImg.Mode.ContentIsMask}
            url={url}
          />
        </button>
      </KeyCommandsRegion>
    );
  }

  _keymapEvent() {
    if (NylasEnv.inDevMode() === true) { console.log("Keymap event fired"); }
    const e = document.getElementById('N1-Unsubscribe');
    e.click()
  }
}

module.exports = {
  ThreadUnsubscribeToolbarButton,
  ThreadUnsubscribeQuickActionButton,
};
