import React from 'react';

class TimespanSelector extends React.Component {
  render() {
    return <div />;
  }
}

class MetricContainer extends React.Component {
  render() {
    return (
      <div className="metric-container">
        {this.props.children}
        <div className="footer">{this.props.name}</div>
      </div>
    );
  }
}

class MetricGraph extends React.Component {
  componentDidMount() {
    window.requestAnimationFrame(() => this._el && this._el.classList.add('visible'));
  }

  render() {
    const { total, values } = this.props;
    const maxValue = Math.max(...values);

    const pointsForSvg = values
      .reverse()
      .map((v, idx) => [(values.length - idx) * 10, (maxValue - v) / maxValue * 10]);

    // make a little diamond at the end
    const [fx, fy] = pointsForSvg[0];
    const diamondRadius = 0.45;
    pointsForSvg.unshift([fx - diamondRadius, fy]);
    pointsForSvg.unshift([fx, fy - diamondRadius]);
    pointsForSvg.unshift([fx + diamondRadius, fy]);
    pointsForSvg.unshift([fx, fy + diamondRadius]);
    pointsForSvg.unshift([fx - diamondRadius, fy]);

    return (
      <div className="metric-graph" ref={el => (this._el = el)}>
        <div className="layer" style={{ zIndex: 1 }}>
          {values.map((_, idx) => (
            <div
              key={idx}
              className="gridline"
              style={{ left: `${(idx + 1) / values.length * 100}%` }}
            />
          ))}
        </div>
        <svg
          className="layer"
          style={{ zIndex: 2, overflow: 'visible' }}
          width="100%"
          height="100%"
          viewBox={`0 0 ${values.length * 10} 10`}
          version="1.1"
        >
          <path d={`M${pointsForSvg.map(([x, y]) => `${x},${y}`).join(' L')}`} />
        </svg>
        <div
          className="layer text-overlay"
          style={{
            zIndex: 3,
          }}
        >
          <div className="text">{total}</div>
        </div>
      </div>
    );
  }
}
export default class Root extends React.Component {
  static displayName = 'ActivityDashboardRoot';

  render() {
    return (
      <div className="activity-dashboard">
        <TimespanSelector />
        <div className="section" style={{ display: 'flex' }}>
          <MetricContainer name="Messages Received">
            <MetricGraph values={[12, 6, 9, 11, 14, 12, 9]} total={123} />
          </MetricContainer>
          <MetricContainer name="Messages Sent" />
          <MetricContainer name="Messages Time of Day" />
        </div>
      </div>
    );
  }
}
