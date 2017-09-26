import React from 'react';
import PropTypes from 'prop-types';
import { shell } from 'electron';
import classnames from 'classnames';
import RetinaImg from './retina-img';
import IdentityStore from '../flux/stores/identity-store';

export default class OpenIdentityPageButton extends React.Component {
  static propTypes = {
    path: PropTypes.string,
    label: PropTypes.string,
    source: PropTypes.string,
    campaign: PropTypes.string,
    img: PropTypes.string,
    isCTA: PropTypes.bool,
  };

  constructor(props) {
    super(props);
    this.state = {
      loading: false,
    };
  }

  _onClick = () => {
    this.setState({ loading: true });
    IdentityStore.fetchSingleSignOnURL(this.props.path, {
      source: this.props.source,
      campaign: this.props.campaign,
      content: this.props.label,
    }).then(url => {
      this.setState({ loading: false });
      shell.openExternal(url);
    });
  };

  render() {
    if (this.state.loading) {
      return (
        <div className="btn btn-disabled">
          <RetinaImg
            name="sending-spinner.gif"
            width={15}
            height={15}
            mode={RetinaImg.Mode.ContentPreserve}
          />
          &nbsp;{this.props.label}&hellip;
        </div>
      );
    }
    if (this.props.img) {
      return (
        <div className="btn" onClick={this._onClick}>
          <RetinaImg name={this.props.img} mode={RetinaImg.Mode.ContentPreserve} />
          &nbsp;&nbsp;{this.props.label}
        </div>
      );
    }
    const cls = classnames({
      btn: true,
      'btn-emphasis': this.props.isCTA,
    });
    return (
      <div className={cls} onClick={this._onClick}>
        {this.props.label}
      </div>
    );
  }
}
