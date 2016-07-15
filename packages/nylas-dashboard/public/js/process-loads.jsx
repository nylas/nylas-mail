const React = window.React;

function ProcessLoads(props) {
  let entries;
  let sumElem;
  if (props.counts == null || Object.keys(props.counts).length === 0) {
    entries = "No Data";
    sumElem = "";
  } else {
    entries = [];
    let sum = 0;
    for (const processName of Object.keys(props.counts).sort()) {
      const count = props.counts[processName];
      sum += count;
      entries.push(
        <div className="load-count">
          <b>{processName}</b>: {count} accounts
        </div>
      );
    }
    sumElem = <div className="sum-accounts">Total Accounts: {sum} </div>
  }

  return (
    <div className="process-loads">
      <div className="section">Process Loads </div>
      {entries}
      {sumElem}
    </div>
  )
}

ProcessLoads.propTypes = {
  counts: React.PropTypes.object,
}

window.ProcessLoads = ProcessLoads;
