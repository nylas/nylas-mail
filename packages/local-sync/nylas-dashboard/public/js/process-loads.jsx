const React = window.React;

function ProcessLoads(props) {
  let entries;
  let sumElem;
  if (props.loads == null || Object.keys(props.loads).length === 0) {
    entries = "No Data";
    sumElem = "";
  } else {
    entries = [];
    let sum = 0;
    for (const processName of Object.keys(props.loads).sort()) {
      const count = props.loads[processName].length;
      sum += count;
      entries.push(
        <div className="load-count" key={processName}>
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
  loads: React.PropTypes.object,
}

window.ProcessLoads = ProcessLoads;
