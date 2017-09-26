import React from 'react';
import PropTypes from 'prop-types';
import Webview from './webview';
import Actions from '../flux/actions';
import IdentityStore from '../flux/stores/identity-store';

export default class BillingModal extends React.Component {
  static IntrinsicWidth = 412;
  static IntrinsicHeight = 540;

  static propTypes = {
    upgradeUrl: PropTypes.string,
    source: PropTypes.string,
  };

  constructor(props = {}) {
    super(props);
    this.state = {
      src: props.upgradeUrl,
    };
  }

  componentWillMount() {
    if (!this.state.src) {
      IdentityStore.fetchSingleSignOnURL('/payment?embedded=true').then(url => {
        if (!this._mounted) return;
        this.setState({ src: url });
      });
    }
  }

  componentDidMount() {
    this._mounted = true;
  }

  /**
   * The Billing modal can get closed for any number of reasons. The user
   * may push escape, click continue below, or click outside of the area.
   * Regardless of the method, Actions.closeModal will fire. The
   * FeatureUsageStore listens for Actions.closeModal and looks at the
   * to determine if the user succesffully paid us or not.
   */
  componentWillUnmount() {
    this._mounted = false;
  }

  _onDidFinishLoad = webview => {
    /**
     * Ahh webviews…
     *
     * First we wait for the payment success screen to pop up and do a
     * quick assertion on the data that's there.
     *
     * We then start listening to the continue button, using the console
     * as a communication bus.
     */
    const receiveUserInfo = `
      var a = document.querySelector('#payment-success-data');
      result = a ? a.innerText : null;
    `;
    webview.executeJavaScript(receiveUserInfo, false, async result => {
      if (!result) return;
      if (result !== IdentityStore.identityId()) {
        AppEnv.reportError(
          new Error(
            'id.getmailspring.com/payment_success did not have a valid #payment-success-data field'
          )
        );
      }
      const listenForContinue = `
        var el = document.querySelector('#continue-btn');
        if (el) {el.addEventListener('click', function(event) {console.log("continue clicked")})}
      `;
      webview.executeJavaScript(listenForContinue);
      webview.addEventListener('console-message', e => {
        if (e.message === 'continue clicked') {
          // See comment on componentWillUnmount
          Actions.closeModal();
        }
      });
      await IdentityStore.fetchIdentity();
    });

    /**
     * If we see any links on the page, we should open them in new
     * windows
     */
    const openExternalLink = `
      var el = document.querySelector('a');
      if (el) {el.addEventListener('click', function(event) {console.log(this.href); event.preventDefault(); return false;})}
    `;
    webview.executeJavaScript(openExternalLink);
  };

  render() {
    return (
      <div className="modal-wrap billing-modal">
        <Webview src={this.state.src} onDidFinishLoad={this._onDidFinishLoad} />
      </div>
    );
  }
}
