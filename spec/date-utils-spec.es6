import moment from 'moment'
import {DateUtils} from 'nylas-exports'


describe('DateUtils', ()=> {
  describe('nextWeek', ()=> {
    it('returns tomorrow if now is sunday', ()=> {
      const sunday = moment("03-06-2016", "MM-DD-YYYY")
      const nextWeek = DateUtils.nextWeek(sunday)
      expect(nextWeek.format('MM-DD-YYYY')).toEqual('03-07-2016')
    });

    it('returns next monday if now is monday', ()=> {
      const monday = moment("03-07-2016", "MM-DD-YYYY")
      const nextWeek = DateUtils.nextWeek(monday)
      expect(nextWeek.format('MM-DD-YYYY')).toEqual('03-14-2016')
    });

    it('returns next monday', ()=> {
      const saturday = moment("03-05-2016", "MM-DD-YYYY")
      const nextWeek = DateUtils.nextWeek(saturday)
      expect(nextWeek.format('MM-DD-YYYY')).toEqual('03-07-2016')
    });
  });

  describe('thisWeekend', ()=> {
    it('returns tomorrow if now is friday', ()=> {
      const friday = moment("03-04-2016", "MM-DD-YYYY")
      const thisWeekend = DateUtils.thisWeekend(friday)
      expect(thisWeekend.format('MM-DD-YYYY')).toEqual('03-05-2016')
    });

    it('returns next saturday if now is saturday', ()=> {
      const saturday = moment("03-05-2016", "MM-DD-YYYY")
      const thisWeekend = DateUtils.thisWeekend(saturday)
      expect(thisWeekend.format('MM-DD-YYYY')).toEqual('03-12-2016')
    });

    it('returns next saturday', ()=> {
      const sunday = moment("03-06-2016", "MM-DD-YYYY")
      const thisWeekend = DateUtils.thisWeekend(sunday)
      expect(thisWeekend.format('MM-DD-YYYY')).toEqual('03-12-2016')
    });
  });
});
