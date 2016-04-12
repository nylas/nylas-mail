import React from 'react'

export default class TopBanner extends React.Component {
  static displayName = "TopBanner";

  static propTypes = {
    bannerComponents: React.PropTypes.node,
  }

  render() {
    if (!this.props.bannerComponents) {
      return false
    }
    return (
      <div className="top-banner">
        {this.props.bannerComponents}
      </div>
    )
  }
}
