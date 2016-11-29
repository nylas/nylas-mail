import {React, ReactDOM} from 'nylas-exports';

setInterval(() => {
  const event = new Event('graphtick')
  window.dispatchEvent(event);
}, 10000);

export default class SyncGraph extends React.Component {
  componentDidMount() {
    this.drawGraph(true);

    this.onGraphTick = () => {
      if (Date.now() - this.props.syncTimestamps[0] > 10000) {
        this.drawGraph(false);
      }
    }
    window.addEventListener('graphtick', this.onGraphTick);
  }

  componentDidUpdate() {
    this.drawGraph(false);
  }

  componentWillUnmount() {
    window.removeEventListener('graphtick', this.onGraphTick);
  }

  drawGraph(isInitial) {
    const now = Date.now();
    const config = SyncGraph.config;
    const node = ReactDOM.findDOMNode(this);
    const context = node.getContext('2d');

    if (isInitial) {
      const totalHeight = config.height + config.labelFontSize + config.labelTopMargin;
      node.width = config.width * 2;
      node.height = totalHeight * 2;
      node.style.width = `${config.width}px`;
      node.style.height = `${totalHeight}px`;
      context.scale(2, 2);

      // Axis labels
      context.fillStyle = config.labelColor;
      context.font = `${config.labelFontSize}px sans-serif`;
      const fontY = config.height + config.labelFontSize + config.labelTopMargin;
      const nowText = "now";
      const nowWidth = context.measureText(nowText).width;
      context.fillText(nowText, config.width - nowWidth - 1, fontY);
      context.fillText("-30m", 1, fontY);
    }

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
  }

  render() {
    return (
      <canvas
        width={SyncGraph.config.width}
        height={SyncGraph.config.height + SyncGraph.config.labelFontSize + SyncGraph.config.labelTopMargin}
        className="sync-graph"
      />
    )
  }

}

SyncGraph.config = {
  height: 50, // Doesn't include labels
  width: 240,
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
  dataColor: '#43a1ff',
}

SyncGraph.propTypes = {
  syncTimestamps: React.PropTypes.arrayOf(React.PropTypes.number),
}
