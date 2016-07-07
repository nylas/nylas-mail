const React = window.React;
const ReactDOM = window.ReactDOM;

class SyncGraph extends React.Component {

  componentDidMount() {
    this.drawGraph();
  }

  componentDidUpdate() {
    this.drawGraph(true);
  }

  drawGraph(isUpdate) {
    const now = Date.now();
    const config = SyncGraph.config;
    const context = ReactDOM.findDOMNode(this).getContext('2d');

    // Background
    // (This hides any previous data points, so we don't have to clear the canvas)
    context.fillStyle = config.backgroundColor;
    context.fillRect(0, 0, config.width, config.height);

    // Data points
    const pxPerSec = config.width / config.timeLength;
    context.strokeStyle = config.dataColor;
    context.beginPath();
    for (const syncTimeMs of this.props.syncTimestamps) {
      const secsAgo = (now - syncTimeMs) / 1000;
      const pxFromRight = secsAgo * pxPerSec;
      const pxFromLeft = config.width - pxFromRight;
      context.moveTo(pxFromLeft, 0);
      context.lineTo(pxFromLeft, config.height);
    }
    context.stroke();

    // Tick marks
    const interval = config.width / config.numTicks;
    context.strokeStyle = config.tickColor;
    context.beginPath();
    for (let px = interval; px < config.width; px += interval) {
      context.moveTo(px, config.height - config.tickHeight);
      context.lineTo(px, config.height);
    }
    context.stroke();

    // Axis labels
    if (!isUpdate) { // only draw these on the initial render
      context.fillStyle = config.labelColor;
      context.font = `${config.labelFontSize}px sans-serif`;
      const fontY = config.height + config.labelFontSize + config.labelTopMargin;
      const nowText = "now";
      const nowWidth = context.measureText(nowText).width;
      context.fillText(nowText, config.width - nowWidth - 1, fontY);
      context.fillText("-30m", 1, fontY);
    }
  }

  render() {
    return (
      <canvas
        width={SyncGraph.config.width}
        height={SyncGraph.config.height + SyncGraph.config.labelFontSize + SyncGraph.config.labelTopMargin}
        className="sync-graph"
        syncTimestamps={this.props.syncTimestamps}
      ></canvas>
    )
  }

}

SyncGraph.config = {
  height: 50, // Doesn't include labels
  width: 300,
  // timeLength is 30 minutes in seconds. If you change this, be sure to update
  // syncGraphTimeLength in sync-worker.js and the axis labels in drawGraph()!
  timeLength: 60 * 30,
  numTicks: 10,
  tickHeight: 10,
  tickColor: 'white',
  labelFontSize: 8,
  labelTopMargin: 2,
  labelColor: 'black',
  backgroundColor: 'black',
  dataColor: 'blue',
}

SyncGraph.propTypes = {
  syncTimestamps: React.PropTypes.arrayOf(React.PropTypes.number),
}

window.SyncGraph = SyncGraph;
