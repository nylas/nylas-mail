const React = window.React;

class ProcessLoads extends React.Component {

  render() {
    let entries;
    if (this.props.counts == null || Object.keys(this.props.counts).length === 0) {
      entries = "No Data"
    }
    else {
      entries = [];
      for (const processName of Object.keys(this.props.counts).sort()) {
        entries.push(
          <div className="load-count">
            <b>{processName}</b>: {this.props.counts[processName]} accounts
          </div>
        );
      }
    }

    return (
      <div className="process-loads">
        <div className="section">Process Loads </div>
        {entries}
      </div>
    )
  }
}

ProcessLoads.propTypes = {
  counts: React.PropTypes.object,
}

window.ProcessLoads = ProcessLoads;
