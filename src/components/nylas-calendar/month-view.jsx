import React from 'react'

export default class MonthView extends React.Component {
  static displayName = "MonthView";

  static propTypes = {
    changeView: React.PropTypes.func,
  }

  constructor(props) {
    super(props);
  }

  _onClick = () => {
    this.props.changeView("WeekView");
  }

  render() {
    return <button onClick={this._onClick}>Change to week</button>
  }

}
