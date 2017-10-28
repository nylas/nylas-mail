import moment from 'moment';

export const DEFAULT_TIMESPAN_ID = '14';

export function getTimespanOptions() {
  return [
    { id: '0', name: 'Today' },
    { id: '7', name: 'Last 7 Days' },
    { id: '14', name: 'Last 2 Weeks' },
    { id: '28', name: 'Last 4 Weeks' },
    { id: '-', name: '-', divider: true },
    ...[0, 1, 2].map(n => {
      return {
        id: `month-${n}`,
        name: moment()
          .subtract(n, 'month')
          .format('MMMM YYYY'),
      };
    }),
  ];
}

export function getTimespanStartEnd(id) {
  if (id.startsWith('month-')) {
    const n = id.split('-').pop() / 1;
    const current = n === 0;
    return [
      moment()
        .startOf('month')
        .subtract(n, 'month')
        .add(1, 'minute'),
      current
        ? moment()
        : moment()
            .startOf('month')
            .subtract(n - 1, 'month')
            .subtract(1, 'minute'),
    ];
  }
  return [
    // Let's say its Friday at 6PM. "Last 7 days" is beginning of last friday through now?
    // That'd technically be 8 days, inclusive. Instead, make it Saturday midnight -> Friday 6PM
    moment()
      .startOf('day')
      .subtract(Math.max(0, id / 1 - 1), 'day')
      .add(1, 'minute'),
    moment(),
  ];
}
