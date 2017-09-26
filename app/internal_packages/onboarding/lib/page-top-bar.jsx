import React from 'react';
import PropTypes from 'prop-types';
import { AccountStore } from 'mailspring-exports';
import { RetinaImg } from 'mailspring-component-kit';
import OnboardingActions from './onboarding-actions';

const PageTopBar = props => {
  const { pageDepth } = props;

  const closeClass = pageDepth > 1 ? 'back' : 'close';
  const closeIcon = pageDepth > 1 ? 'onboarding-back.png' : 'onboarding-close.png';
  const closeAction = () => {
    const webview = document.querySelector('webview');
    if (webview && webview.canGoBack()) {
      webview.goBack();
    } else if (pageDepth > 1) {
      OnboardingActions.moveToPreviousPage();
    } else {
      if (AccountStore.accounts().length === 0) {
        AppEnv.quit();
      } else {
        AppEnv.close();
      }
    }
  };

  let backButton = (
    <div className={closeClass} onClick={closeAction}>
      <RetinaImg name={closeIcon} mode={RetinaImg.Mode.ContentPreserve} />
    </div>
  );
  if (props.pageDepth > 1 && !props.allowMoveBack) {
    backButton = null;
  }

  return (
    <div
      className="dragRegion"
      style={{
        top: 0,
        left: 26,
        right: 0,
        height: 27,
        zIndex: 100,
        position: 'absolute',
        WebkitAppRegion: 'drag',
      }}
    >
      {backButton}
    </div>
  );
};

PageTopBar.propTypes = {
  pageDepth: PropTypes.number,
  allowMoveBack: PropTypes.bool,
};

export default PageTopBar;
