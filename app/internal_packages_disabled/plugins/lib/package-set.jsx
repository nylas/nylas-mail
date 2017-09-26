import React from 'react';
import PropTypes from 'prop-types';

import Package from './package';

class PackageSet extends React.Component {
  static propTypes = {
    title: PropTypes.string.isRequired,
    packages: PropTypes.array,
    emptyText: PropTypes.element,
    showVersions: PropTypes.bool,
  };

  render() {
    if (!this.props.packages) return false;

    const packages = this.props.packages.map(pkg => (
      <Package key={pkg.name} package={pkg} showVersions={this.props.showVersions} />
    ));
    let count = <span>({this.props.packages.length})</span>;

    if (packages.length === 0) {
      count = [];
      packages.push(
        <div key="empty" className="empty">
          {this.props.emptyText || 'No plugins to display.'}
        </div>
      );
    }

    return (
      <div className="package-set">
        <h6>
          {this.props.title} {count}
        </h6>
        {packages}
      </div>
    );
  }
}

export default PackageSet;
