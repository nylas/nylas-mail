/* eslint react/prefer-stateless-function: 0 */
import React from 'react';

export default class InjectedComponentLabel extends React.Component {
  static displayName = 'InjectedComponentLabel';

  static propTypes = {
    matching: React.PropTypes.object,
  };

  render() {
    const matchingDescriptions = [];

    for (const key of Object.keys(this.props.matching)) {
      let val = this.props.matching[key];
      if (key === 'location') {
        val = val.id;
      }
      if (key === 'locations') {
        val = val.map(v => v.id);
      }
      matchingDescriptions.push(`${key}: ${val}`);
    }

    const propDescriptions = [];
    for (const key of Object.keys(this.props)) {
      const val = this.props[key];
      if (key === 'matching') {
        continue;
      }
      propDescriptions.push(`${key}:<${val.constructor ? val.constructor.name : typeof val}>`);
    }

    let description = ` ${matchingDescriptions.join(', ')}`;
    if (propDescriptions.length > 0) {
      description += ` (${propDescriptions.join(', ')})`;
    }

    return (
      <span className="name">
        {description}
      </span>
    );
  }
}
