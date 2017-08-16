import _ from 'underscore';
import React from 'react';
import {RetinaImg, Flexbox} from 'nylas-component-kit';
import {makeRequest} from '../flux/nylas-api-request';

export default class NewsletterSignup extends React.Component {
  static displayName = 'NewsletterSignup';
  static propTypes = {
    name: React.PropTypes.string,
    emailAddress: React.PropTypes.string,
  };

  constructor(props) {
    super(props);
    this.state = {status: 'Pending'};
  }

  componentDidMount() {
    this._mounted = true;
    return this._onGetStatus();
  }

  componentWillReceiveProps(nextProps) {
    if (!_.isEqual(this.props, nextProps)) {
      this._onGetStatus(nextProps);
    }
  }

  componentWillUnmount() {
    this._mounted = false;
  }

  _setState(state) {
    if (!this._mounted) { return; }
    this.setState(state);
  }

  _onGetStatus = async (props = this.props) => {
    this._setState({status: 'Pending'});
    try {
      const {status} = await makeRequest({
        server: 'identity',
        method: 'GET',
        path: this._path(props),
      })
      if (status === 'Never Subscribed') {
        this._onSubscribe();
      } else {
        this._setState({status});
      }
    } catch (err) {
      this._setState({status: "Error"});
    }
  }

  _onSubscribe = async () => {
    this._setState({status: 'Pending'});
    try {
      const {status} = await makeRequest({
        server: 'identity',
        method: 'POST',
        path: this._path(),
      });
      this._setState({status});
    } catch (err) {
      this._setState({status: "Error"});
    }
  }

  _onUnsubscribe = () => {
    this._setState({status: 'Pending'});
    try {
      const {status} = makeRequest({
        server: 'identity',
        method: 'DELETE',
        path: this._path(),
      });
      this._setState({status});
    } catch (err) {
      this._setState({status: "Error"});
    }
  }

  _path(props = this.props) {
    return `/api/newsletter-subscription/${encodeURIComponent(props.emailAddress)}?name=${encodeURIComponent(props.name)}`;
  }

  _renderControl() {
    if (this.state.status === 'Pending') {
      return (<RetinaImg name="inline-loading-spinner.gif" mode={RetinaImg.Mode.ContentDark} style={{width: 14, height: 14}} />);
    }
    if (this.state.status === 'Error') {
      return (<button onClick={() => this._onGetStatus()} className="btn">Retry</button>);
    }
    if (this.state.status === 'Subscribed') {
      return (<input id="subscribe-check" type="checkbox" checked style={{marginTop: 3}} onChange={this._onUnsubscribe} />);
    }
    return (<input id="subscribe-check" type="checkbox" checked={false} style={{marginTop: 3}} onChange={this._onSubscribe} />);
  }

  render() {
    return (
      <Flexbox direction="row" height="auto" style={{textAlign: 'left'}}>
        <div style={{minWidth: 15}}>
          {this._renderControl()}
        </div>
        <label htmlFor="subscribe-check" style={{paddingLeft: 4, flex: 1}}>
          Notify me about new features and plugins via this email address.
        </label>
      </Flexbox>
    );
  }
}
