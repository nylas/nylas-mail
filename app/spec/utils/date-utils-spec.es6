import moment from 'moment';
import { DateUtils } from 'mailspring-exports';

describe('DateUtils', function dateUtils() {
  describe('nextWeek', () => {
    it('returns tomorrow if now is sunday', () => {
      const sunday = moment('03-06-2016', 'MM-DD-YYYY');
      const nextWeek = DateUtils.nextWeek(sunday);
      expect(nextWeek.format('MM-DD-YYYY')).toEqual('03-07-2016');
    });

    it('returns next monday if now is monday', () => {
      const monday = moment('03-07-2016', 'MM-DD-YYYY');
      const nextWeek = DateUtils.nextWeek(monday);
      expect(nextWeek.format('MM-DD-YYYY')).toEqual('03-14-2016');
    });

    it('returns next monday', () => {
      const saturday = moment('03-05-2016', 'MM-DD-YYYY');
      const nextWeek = DateUtils.nextWeek(saturday);
      expect(nextWeek.format('MM-DD-YYYY')).toEqual('03-07-2016');
    });
  });

  describe('thisWeekend', () => {
    it('returns tomorrow if now is friday', () => {
      const friday = moment('03-04-2016', 'MM-DD-YYYY');
      const thisWeekend = DateUtils.thisWeekend(friday);
      expect(thisWeekend.format('MM-DD-YYYY')).toEqual('03-05-2016');
    });

    it('returns next saturday if now is saturday', () => {
      const saturday = moment('03-05-2016', 'MM-DD-YYYY');
      const thisWeekend = DateUtils.thisWeekend(saturday);
      expect(thisWeekend.format('MM-DD-YYYY')).toEqual('03-12-2016');
    });

    it('returns next saturday', () => {
      const sunday = moment('03-06-2016', 'MM-DD-YYYY');
      const thisWeekend = DateUtils.thisWeekend(sunday);
      expect(thisWeekend.format('MM-DD-YYYY')).toEqual('03-12-2016');
    });
  });

  describe('getTimeFormat: 12-hour clock', () => {
    beforeEach(() => {
      spyOn(AppEnv.config, 'get').andReturn(false);
    });

    it('displays the time format for a 12-hour clock', () => {
      const time = DateUtils.getTimeFormat(null);
      expect(time).toBe('h:mm a');
    });

    it('displays the time format for a 12-hour clock with timezone', () => {
      const opts = { timeZone: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('h:mm a z');
    });

    it('displays the time format for a 12-hour clock with seconds', () => {
      const opts = { seconds: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('h:mm:ss a');
    });

    it('displays the time format for a 12-hour clock with seconds and timezone', () => {
      const opts = { seconds: true, timeZone: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('h:mm:ss a z');
    });

    it('displays the time format for a 12-hour clock in uppercase', () => {
      const opts = { upperCase: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('h:mm A');
    });

    it('displays the time format for a 12-hour clock in uppercase with seconds', () => {
      const opts = { upperCase: true, seconds: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('h:mm:ss A');
    });

    it('displays the time format for a 12-hour clock in uppercase with timezone', () => {
      const opts = { upperCase: true, timeZone: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('h:mm A z');
    });

    it('displays the time format for a 12-hour clock in uppercase with seconds and timezone', () => {
      const opts = { upperCase: true, seconds: true, timeZone: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('h:mm:ss A z');
    });
  });

  describe('getTimeFormat: 24-hour clock', () => {
    beforeEach(() => {
      spyOn(AppEnv.config, 'get').andReturn(true);
    });

    it('displays the time format for a 24-hour clock', () => {
      const time = DateUtils.getTimeFormat(null);
      expect(time).toBe('HH:mm');
    });

    it('displays the time format for a 24-hour clock with timezone', () => {
      const opts = { timeZone: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('HH:mm z');
    });

    it('displays the time format for a 24-hour clock with seconds', () => {
      const opts = { seconds: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('HH:mm:ss');
    });

    it('displays the time format for a 24-hour clock with seconds and timezone', () => {
      const opts = { seconds: true, timeZone: true };
      const time = DateUtils.getTimeFormat(opts);
      expect(time).toBe('HH:mm:ss z');
    });
  });

  describe('mediumTimeString: 12-hour time', () => {
    beforeEach(() => {
      spyOn(AppEnv.config, 'get').andReturn(false);
    });

    it('displays a date and time', () => {
      const datestring = DateUtils.mediumTimeString('1982-10-24 22:45');
      expect(datestring).toBe('October 24, 1982, 10:45 PM');
    });
  });

  describe('mediumTimeString: 24-hour time', () => {
    beforeEach(() => {
      spyOn(AppEnv.config, 'get').andReturn(true);
    });

    it('displays a date and time', () => {
      const datestring = DateUtils.mediumTimeString('1982-10-24 22:45');
      expect(datestring).toBe('October 24, 1982, 22:45');
    });
  });

  describe('fullTimeString: 12-hour time', () => {
    beforeEach(() => {
      spyOn(AppEnv.config, 'get').andReturn(false);
    });

    it('displays a date and time', () => {
      const datestring = DateUtils.fullTimeString('1982-10-24 22:45');
      expect(datestring.startsWith(`Sunday, October 24th 1982, 10:45:00 PM`)).toBe(true);
    });
  });

  describe('fullTimeString: 24-hour time', () => {
    beforeEach(() => {
      spyOn(AppEnv.config, 'get').andReturn(true);
    });

    it('displays a date and time', () => {
      const datestring = DateUtils.fullTimeString('1982-10-24 22:45');
      expect(datestring.startsWith(`Sunday, October 24th 1982, 22:45:00`)).toBe(true);
    });
  });
});
