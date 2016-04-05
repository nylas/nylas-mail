import React from 'react';

import Package from './package';


class PackageSet extends React.Component {

  static propTypes = {
    title: React.PropTypes.string.isRequired,
    packages: React.PropTypes.array,
    emptyText: React.PropTypes.element,
  }

  render() {
    if (!this.props.packages) return false;

    const packages = this.props.packages.map((pkg) =>
      <Package key={pkg.name} package={pkg} />
    );
    let count = <span>({this.props.packages.length})</span>

    if (packages.length === 0) {
      count = [];
      packages.push(
        <div key="empty" className="empty">{this.props.emptyText || "No plugins to display."}</div>
      )
    }

    return (
      <div className="package-set">
        <h6>{this.props.title} {count}</h6>
        {packages}
      </div>
    );
  }

}

export default PackageSet;
