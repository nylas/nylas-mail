import { Actions, React, PropTypes } from 'nylas-exports';

function SyncingListState(props) {
  let message = 'Looking for more messages';
  if (props.empty) {
    message = 'Looking for messages';
  }
  return (
    <div className="syncing-list-state" style={{ width: '100%', textAlign: 'center' }}>
      {message}&hellip;
      <br />
      <a onClick={Actions.expandInitialSyncState}>Show Progress</a>
    </div>
  );
}

SyncingListState.propTypes = {
  empty: PropTypes.bool,
};

export default SyncingListState;
