import moment from 'moment';

export function getTimespanOptions() {
  return [
    { id: '0', name: 'Today' },
    { id: '6', name: 'Last 7 Days' },
    { id: '13', name: 'Last 2 Weeks' },
    { id: '27', name: 'Last 4 Weeks' },
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
    moment()
      .startOf('day')
      .subtract(id / 1, 'day')
      .add(1, 'minute'),
    moment(),
  ];
}
