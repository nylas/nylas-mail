export function pluginFor(id) {
  const openTrackingId = AppEnv.packages.pluginIdFor('open-tracking');
  const linkTrackingId = AppEnv.packages.pluginIdFor('link-tracking');
  if (id === openTrackingId) {
    return {
      name: 'open',
      predicate: 'opened',
      iconName: 'icon-activity-mailopen.png',
      notificationInterval: 600000, // 10 minutes in ms
    };
  }
  if (id === linkTrackingId) {
    return {
      name: 'link',
      predicate: 'clicked',
      iconName: 'icon-activity-linkopen.png',
      notificationInterval: 10000, // 10 seconds in ms
    };
  }
  return undefined;
}
