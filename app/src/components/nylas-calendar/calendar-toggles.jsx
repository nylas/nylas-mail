/* eslint jsx-a11y/label-has-for: 0 */
import _ from 'underscore';
import classnames from 'classnames';
import React from 'react';
import PropTypes from 'prop-types';

import { calcColor } from './calendar-helpers';

const DISABLED_CALENDARS = 'nylas.disabledCalendars';

function renderCalendarToggles(calendars, disabledCalendars) {
  return calendars.map(calendar => {
    const calendarId = calendar.id;
    const onClick = () => {
      const cals = AppEnv.config.get(DISABLED_CALENDARS) || [];
      if (cals.includes(calendarId)) {
        cals.splice(cals.indexOf(calendarId), 1);
      } else {
        cals.push(calendarId);
      }
      AppEnv.config.set(DISABLED_CALENDARS, cals);
    };

    const checked = !disabledCalendars.includes(calendar.id);
    const checkboxClass = classnames({
      'colored-checkbox': true,
      checked: checked,
    });
    const bgColor = checked ? calcColor(calendar.id) : 'transparent';
    return (
      <div
        title={calendar.name}
        onClick={onClick}
        className="toggle-wrap"
        key={`check-${calendar.id}`}
      >
        <div className={checkboxClass}>
          <div className="bg-color" style={{ backgroundColor: bgColor }} />
        </div>
        <label>{calendar.name}</label>
      </div>
    );
  });
}

export default function CalendarToggles(props) {
  const calsByAccountId = _.groupBy(props.calendars, 'accountId');
  const accountSections = [];
  for (const accountId of Object.keys(calsByAccountId)) {
    const calendars = calsByAccountId[accountId];
    const account = props.accounts.find(a => a.id === accountId);
    if (!account || !calendars || calendars.length === 0) {
      continue;
    }
    accountSections.push(
      <div key={accountId} className="account-calendars-wrap">
        <div className="account-label">{account.label}</div>
        {renderCalendarToggles(calendars, props.disabledCalendars)}
      </div>
    );
  }
  return <div className="calendar-toggles-wrap">{accountSections}</div>;
}

CalendarToggles.propTypes = {
  accounts: PropTypes.array,
  calendars: PropTypes.array,
  disabledCalendars: PropTypes.array,
};
