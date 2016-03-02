import React from 'react'
import {Utils} from 'nylas-exports'

export default class SearchMatch extends React.Component {
  static displayName = "SearchMatch";

  static propTypes = {
    regionId: React.PropTypes.string,
    className: React.PropTypes.string,
    renderIndex: React.PropTypes.number,
  }

  render() {
    return (
      <span data-region-id={this.props.regionId}
            data-render-index={this.props.renderIndex}
            className={`search-match ${this.props.className}`}>{this.props.children}</span>
    )
  }
}

