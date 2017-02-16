import {OnlineStatusStore, React, Actions} from 'nylas-exports';
import {Notification, ListensToFluxStore} from 'nylas-component-kit';


function OfflineNotification({isOnline, retryingInSeconds}) {
  if (isOnline) {
    return false
  }
  const subtitle = retryingInSeconds ?
    `Retrying in ${retryingInSeconds} second${retryingInSeconds > 1 ? 's' : ''}` :
    `Retrying now...`;

  return (
    <Notification
      className="offline"
      title="Nylas Mail is offline"
      subtitle={subtitle}
      priority="5"
      icon="volstead-offline.png"
      actions={[{
        id: 'try_now',
        label: 'Try now',
        fn: () => Actions.checkOnlineStatus(),
      }]}
    />
  )
}
OfflineNotification.displayName = 'OfflineNotification'
OfflineNotification.propTypes = {
  isOnline: React.PropTypes.bool,
  retryingInSeconds: React.PropTypes.number,
}

export default ListensToFluxStore(OfflineNotification, {
  stores: [OnlineStatusStore],
  getStateFromStores() {
    return {
      isOnline: OnlineStatusStore.isOnline(),
      retryingInSeconds: OnlineStatusStore.retryingInSeconds(),
    }
  },
})
