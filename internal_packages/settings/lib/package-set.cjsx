React = require 'react'
Package = require './package'

class PackageSet extends React.Component
  @propTypes:
    'title': React.PropTypes.string.isRequired
    'packages': React.PropTypes.array.isRequired
    'emptyText': React.PropTypes.string

  render: ->
    packages = @props.packages.map (pkg) -> <Package package={pkg} />
    count = <span>({@props.packages.length})</span>

    if packages.length is 0
      count = []
      packages.push(
        <div className="empty">{@props.emptyText ? "No packages to display."}</div>
      )

    <div className="package-set">
      <h2>{@props.title} {count}</h2>
      { packages }
    </div>

module.exports = PackageSet
