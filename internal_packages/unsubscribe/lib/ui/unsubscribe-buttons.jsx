import {React} from 'nylas-exports';
import {RetinaImg, KeyCommandsRegion} from 'nylas-component-kit';
import ThreadUnsubscribeStoreManager from '../thread-unsubscribe-store-manager';
import ThreadConditionType from '../enum/threadConditionType';

const UNSUBSCRIBE_ASSETS_BASE_URL = 'nylas://unsubscribe/assets/';

class ThreadUnsubscribeButton extends React.Component {

  static containerRequired = false;

  constructor(props) {
    super(props);
    this.state = {
      condition: ThreadConditionType.LOADING,
      hasLinks: false,
    };
    this.onClick = this.onClick.bind(this);
  }

  componentWillMount() {
    this.load(this.props);
  }

  componentWillReceiveProps(newProps) {
    this.load(newProps);
  }

  componentWillUnmount() {
    return this.unload();
  }

  onMessageLoad(threadState) {
    this.setState(threadState);
  }

  onClick(event) {
    this.tuStore.unsubscribe();
    event.stopPropagation()
  }

  getIconInfo(name : string, ratio : number) {
    let url = UNSUBSCRIBE_ASSETS_BASE_URL;
    let buttonTitle;
    let extraClasses;
    let scale = ratio;

    if (typeof scale === 'undefined') {
      scale = Math.ceil(window.devicePixelRatio);
      if (scale !== 1 || scale !== 2) { scale = 2; }
    }

    url += name;
    switch (this.state.condition) {
      case ThreadConditionType.UNSUBSCRIBED:
        extraClasses = 'unsubscribe-success';
        buttonTitle = 'Unsubscribe (Success)';
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
      case ThreadConditionType.READY:
        extraClasses = 'unsubscribe-ready';
        buttonTitle = 'Unsubscribe';
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
    this.tuStore._triggerUpdate();
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

export class ThreadUnsubscribeQuickActionButton extends ThreadUnsubscribeButton {

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
        onClick={this.onClick}
      />
    );
  }
}

export class ThreadUnsubscribeToolbarButton extends ThreadUnsubscribeButton {

  static displayName = 'ThreadUnsubscribeToolbarButton';

  _keymapHandlers() {
    return {"unsubscribe:unsubscribe": this._keymapEvent}
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
          id={'unsubscribe'}
          className={`btn btn-toolbar toolbar-unsubscribe ${extraClasses}`}
          onClick={this.onClick}
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
    const e = document.getElementById('unsubscribe');
    e.click()
  }
}
