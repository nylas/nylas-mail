React = require 'react'
Package = require './package'

class PackageSet extends React.Component
  @propTypes:
    title: React.PropTypes.string.isRequired
    packages: React.PropTypes.array.isRequired
    emptyText: React.PropTypes.element

  render: ->
    return false unless @props.packages
    packages = @props.packages.map (pkg) -> <Package key={pkg.name} package={pkg} />
    count = <span>({@props.packages.length})</span>

    if packages.length is 0
      count = []
      packages.push(
        <div key="empty" className="empty">{@props.emptyText ? "No plugins to display."}</div>
      )

    <div className="package-set">
      <h2>{@props.title} {count}</h2>
      { packages }
    </div>

module.exports = PackageSet
