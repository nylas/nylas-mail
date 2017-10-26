import React from 'react';

export class MetricContainer extends React.Component {
  render() {
    return (
      <div className="metric-container">
        {this.props.children}
        <div className="footer">{this.props.name}</div>
      </div>
    );
  }
}

export class MetricStat extends React.Component {
  render() {
    const { value, units } = this.props;

    return (
      <div className="metric-stat" ref={el => (this._el = el)}>
        <div
          className="layer text-overlay"
          style={{
            zIndex: 3,
          }}
        >
          <div className="text">{`${(value / 1).toLocaleString()}${units}`}</div>
        </div>
      </div>
    );
  }
}

export class MetricHistogram extends React.Component {
  componentDidMount() {
    if (!this.props.loading) {
      window.requestAnimationFrame(() => this._el && this._el.classList.add('visible'));
    }
  }

  render() {
    const { values, left, right } = this.props;
    let max = 0;
    for (const v of values) {
      max = Math.max(v, max);
    }

    return (
      <div className="metric-histogram" ref={el => (this._el = el)}>
        <div className="legend">
          <div>{left}</div>
          <div style={{ flex: 1 }} />
          <div>{right}</div>
        </div>
        <div className="layer" style={{ zIndex: 2, top: '20%' }}>
          {values.map((value, idx) => (
            <div
              key={idx}
              className="column"
              style={{
                transitionDelay: `${idx * Math.round(800 / values.length)}ms`,
                left: `${(idx + 1) / values.length * 100}%`,
                height: `${value / max * 100}%`,
                width: `${100 / values.length}%`,
              }}
            />
          ))}
        </div>
      </div>
    );
  }
}

export class MetricGraph extends React.Component {
  componentDidMount() {
    if (!this.props.loading) {
      window.requestAnimationFrame(() => this._el && this._el.classList.add('visible'));
    }
  }

  render() {
    const { values } = this.props;
    const total = values.reduce((a, sum) => (sum += a), 0);
    const maxValue = Math.max(...values) || 1;
    const step = 100.0 / values.length;

    const pointsForSvg = values
      .reverse()
      .map((v, idx) => [(values.length - idx) * step, (maxValue - v) / maxValue * 10]);

    // make a little diamond at the end
    if (pointsForSvg[0]) {
      const [fx, fy] = pointsForSvg[0];
      const diamondRadius = 0.45;
      pointsForSvg.unshift([fx - diamondRadius, fy]);
      pointsForSvg.unshift([fx, fy - diamondRadius]);
      pointsForSvg.unshift([fx + diamondRadius, fy]);
      pointsForSvg.unshift([fx, fy + diamondRadius]);
      pointsForSvg.unshift([fx - diamondRadius, fy]);
    } else {
      // avoid rendering an invalid SVG by making a single point
      pointsForSvg[0] = [0, 0];
    }

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
          viewBox={`0 0 100 10`}
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
          <div className="text">{(total / 1).toLocaleString()}</div>
        </div>
      </div>
    );
  }
}
