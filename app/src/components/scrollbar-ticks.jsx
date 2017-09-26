import React from 'react';
import ReactDOM from 'react-dom';
import PropTypes from 'prop-types';

export default class ScrollbarTicks extends React.Component {
  static displayName = 'ScrollbarTicks';

  static propTypes = {
    ticks: PropTypes.array,
  };

  componentDidMount() {
    this._updateTicks();
  }

  componentDidUpdate() {
    this._updateTicks();
  }

  _updateTicks() {
    const html = this.props.ticks
      .map(percentData => {
        let percent;
        let className = '';
        if (typeof percentData === 'number') {
          percent = percentData;
        } else {
          percent = percentData.percent;
          className = ` ${percentData.className}`;
        }
        return `<div class="t${className}" style="top: ${percent * 100}%" />`;
      })
      .join('');
    ReactDOM.findDOMNode(this).innerHTML = html;
  }

  render() {
    return <div className="scrollbar-ticks" />;
  }
}
