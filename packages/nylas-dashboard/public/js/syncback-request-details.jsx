const React = window.React;
const Dropdown = window.Dropdown;

class SyncbackRequestDetails extends React.Component {
  constructor(props) {
    super(props);
    this.state = {
      open: false,
      accountId: props.accountId,
      syncbackRequests: null,
      counts: null,
      statusFilter: 'all',
    };
  }

  getDetails() {
    const req = new XMLHttpRequest();
    const url = `${window.location.protocol}/syncback-requests/${this.state.accountId}`;
    req.open("GET", url, true);
    req.onreadystatechange = () => {
      if (req.readyState === XMLHttpRequest.DONE) {
        if (req.status === 200) {
          this.setState({syncbackRequests: req.responseText});
        } else {
          console.error(req.responseText);
        }
      }
    }
    req.send();
  }

  getCounts() {
    const since = Date.now() - 1000 * 60 * 60; // one hour ago
    const req = new XMLHttpRequest();
    const url = `${window.location.protocol}/syncback-requests/${this.state.accountId}/counts?since=${since}`;
    req.open("GET", url, true);
    req.onreadystatechange = () => {
      if (req.readyState === XMLHttpRequest.DONE) {
        if (req.status === 200) {
          this.setState({counts: JSON.parse(req.responseText)});
        } else {
          console.error(req.responseText);
        }
      }
    }
    req.send();
  }

  setStatusFilter(statusFilter) {
    this.setState({statusFilter: statusFilter});
  }

  open() {
    this.getDetails();
    this.getCounts();
    this.setState({open: true});
  }

  close() {
    this.setState({open: false});
  }

  render() {
    if (this.state.open) {
      let counts = <span> Of requests created in the last hour: ... </span>
      if (this.state.counts) {
        const total = this.state.counts.new + this.state.counts.failed
          + this.state.counts.succeeded;
        if (total === 0) {
          counts = "No requests made in the last hour";
        } else {
          counts = (
            <div className="counts">
              Of requests created in the last hour:
              <span
                style={{color: 'rgb(222, 68, 68)'}}
                title={`${this.state.counts.failed} out of ${total}`}
              >
                {this.state.counts.failed / total * 100}&#37; failed
              </span>
              <span
                style={{color: 'green'}}
                title={`${this.state.counts.succeeded} out of ${total}`}
              >
                {this.state.counts.succeeded / total * 100}&#37; succeeded
              </span>
              <span
                style={{color: 'rgb(98, 98, 179)'}}
                title={`${this.state.counts.new} out of ${total}`}
              >
                {/* .new was throwing off my syntax higlighting, so ignoring linter*/}
                {this.state.counts['new'] / total * 100}&#37; are still new
              </span>
            </div>
          )
        }
      }

      let details = "Loading..."
      if (this.state.syncbackRequests) {
        let reqs = JSON.parse(this.state.syncbackRequests);
        if (this.state.statusFilter !== 'all') {
          reqs = reqs.filter((req) => req.status === this.state.statusFilter);
        }
        let rows = [];
        if (reqs.length === 0) {
          rows.push(<tr><td>No results</td><td>-</td><td>-</td></tr>);
        }
        for (let i = reqs.length - 1; i >= 0; i--) {
          const req = reqs[i];
          const date = new Date(req.createdAt);
          rows.push(<tr key={req.id} title={`id: ${req.id}`}>
            <td> {req.status} </td>
            <td> {req.type} </td>
            <td> {date.toLocaleTimeString()}, {date.toLocaleDateString()} </td>
          </tr>)
        }
        details = (
          <table>
            <tbody>
              <tr>
                <th>
                  Status:&nbsp;
                  <Dropdown
                    options={['all', 'FAILED', 'NEW', 'SUCCEEDED']}
                    defaultOption="all"
                    onSelect={(status) => this.setStatusFilter.call(this, status)}
                  />
                </th>
                <th> Type </th>
                <th> Created At </th>
              </tr>
              {rows}
            </tbody>
          </table>
        );
      }

      return (
        <div>
          <span className="action-link">Syncback Request Details </span>
          <div className="modal-bg">
            <div className="modal">
              <div className="modal-close" onClick={() => this.close.call(this)}>
                X
              </div>
              <div id="syncback-request-details">
                {counts}
                {details}
              </div>
            </div>
          </div>
        </div>
      );
    }
    // else, the modal isn't open
    return (
      <div>
        <span className="action-link" onClick={() => this.open.call(this)}>
          Syncback Request Details
        </span>
      </div>
    );
  }
}

SyncbackRequestDetails.propTypes = {
  accountId: React.PropTypes.number,
}

window.SyncbackRequestDetails = SyncbackRequestDetails;
