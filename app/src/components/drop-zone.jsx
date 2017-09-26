import React from 'react';
import PropTypes from 'prop-types';
import _ from 'underscore';

export default class DropZone extends React.Component {
  static propTypes = {
    shouldAcceptDrop: PropTypes.func.isRequired,
    onDrop: PropTypes.func.isRequired,
    onDragOver: PropTypes.func,
    onDragStateChange: PropTypes.func,
  };

  static defaultProps = {
    onDragOver: () => {},
  };

  // We maintain a "dragCounter" because dragEnter and dragLeave events *stack*
  // when the user moves the item in and out of DOM elements inside of our container.
  // It's really awful and everyone hates it.

  // Alternative solution *maybe* is to set pointer-events:none; during drag.

  _onDragEnter = e => {
    if (!this.props.shouldAcceptDrop(e)) {
      return;
    }
    if (this._dragCounter === undefined) {
      this._dragCounter = 0;
    }
    this._dragCounter += 1;
    if (this._dragCounter === 1 && this.props.onDragStateChange) {
      this.props.onDragStateChange({ isDropping: true });
    }
    e.stopPropagation();
    return;
  };

  _onDragLeave = e => {
    if (!this.props.shouldAcceptDrop(e)) {
      return;
    }
    this._dragCounter -= 1;
    if (this._dragCounter === 0 && this.props.onDragStateChange) {
      this.props.onDragStateChange({ isDropping: false });
    }
    e.stopPropagation();
    return;
  };

  _onDrop = e => {
    if (!this.props.shouldAcceptDrop(e)) {
      return;
    }
    if (this.props.onDragStateChange) {
      this.props.onDragStateChange({ isDropping: false });
    }
    this._dragCounter = 0;
    this.props.onDrop(e);
    e.stopPropagation();
    return;
  };

  render() {
    const otherProps = _.omit(this.props, Object.keys(this.constructor.propTypes));
    return (
      <div
        {...otherProps}
        onDragOver={this.props.onDragOver}
        onDragEnter={this._onDragEnter}
        onDragLeave={this._onDragLeave}
        onDrop={this._onDrop}
      >
        {this.props.children}
      </div>
    );
  }
}
