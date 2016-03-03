import React from 'react'

export default class ScrollbarTicks extends React.Component {
  static displayName = "ScrollbarTicks";

  static propTypes = {
    ticks: React.PropTypes.array,
  }

  componentDidMount() {
    this._updateTicks()
  }

  componentDidUpdate() {
    this._updateTicks()
  }

  _updateTicks() {
    const html = this.props.ticks.map((percentData) => {
      let percent;
      let className = ""
      if (typeof percentData === "number") {
        percent = percentData;
      } else {
        percent = percentData.percent;
        className = " " + percentData.className
      }
      return `<div class="t${className}" style="top: ${percent * 100}%"></div>`
    }).join("")
    React.findDOMNode(this).innerHTML = html
  }

  render() {
    return <div className="scrollbar-ticks"></div>
  }
}
