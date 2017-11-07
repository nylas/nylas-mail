import React from 'react';
import PropTypes from 'prop-types';

import { RetinaImg } from 'mailspring-component-kit';

export default class LoadingCover extends React.Component {
  static propTypes = {
    active: PropTypes.bool,
  };

  render() {
    return (
      <div className={`loading-cover ${this.props.active && 'active'}`}>
        <div className="loading-indicator">
          <RetinaImg name="activity-loading-mask.png" mode={RetinaImg.Mode.ContentIsMask} />
        </div>
      </div>
    );
  }
}
