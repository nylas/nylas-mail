import React from 'react';
import PropTypes from 'prop-types';

export default class MonthView extends React.Component {
  static displayName = 'MonthView';

  static propTypes = {
    changeView: PropTypes.func,
  };

  _onClick = () => {
    this.props.changeView('WeekView');
  };

  render() {
    return <button onClick={this._onClick}>Change to week</button>;
  }
}
