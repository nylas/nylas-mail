const React = window.React;

function AccountFilter(props) {
  return (
    <div>
      Display: <select {...props}>
        <option value={AccountFilter.states.all}>All Accounts</option>
        <option value={AccountFilter.states.errored}>Accounts with Errors</option>
        <option value={AccountFilter.states.notErrored}>Accounts without Errors</option>
      </select>
    </div>
  )
}

AccountFilter.propTypes = {
  onChange: React.PropTypes.func,
  id: React.PropTypes.string,
}

AccountFilter.states = {
  all: "all",
  errored: "errored",
  notErrored: "not-errored",
};

window.AccountFilter = AccountFilter;
