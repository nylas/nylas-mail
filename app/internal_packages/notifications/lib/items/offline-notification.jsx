import { OnlineStatusStore, React, PropTypes, Actions } from 'mailspring-exports';
import { Notification, ListensToFluxStore } from 'nylas-component-kit';

function OfflineNotification({ isOnline, retryingInSeconds }) {
  if (isOnline) {
    return false;
  }
  const subtitle = retryingInSeconds
    ? `Retrying in ${retryingInSeconds} second${retryingInSeconds > 1 ? 's' : ''}`
    : `Retrying now...`;

  return (
    <Notification
      className="offline"
      title="Mailspring is offline"
      subtitle={subtitle}
      priority="5"
      icon="volstead-offline.png"
      actions={[
        {
          id: 'try_now',
          label: 'Try now',
          fn: () => Actions.checkOnlineStatus(),
        },
      ]}
    />
  );
}
OfflineNotification.displayName = 'OfflineNotification';
OfflineNotification.propTypes = {
  isOnline: PropTypes.bool,
  retryingInSeconds: PropTypes.number,
};

export default ListensToFluxStore(OfflineNotification, {
  stores: [OnlineStatusStore],
  getStateFromStores() {
    return {
      isOnline: OnlineStatusStore.isOnline(),
      retryingInSeconds: OnlineStatusStore.retryingInSeconds(),
    };
  },
});
