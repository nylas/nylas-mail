/* eslint quote-props: 0 */
import ModelQuery from '../../src/flux/models/query';
import Attributes from '../../src/flux/attributes';
import Message from '../../src/flux/models/message';
import Thread from '../../src/flux/models/thread';
import Account from '../../src/flux/models/account';

describe('ModelQuery', function ModelQuerySpecs() {
  beforeEach(() => {
    this.db = {};
  });

  describe('where', () => {
    beforeEach(() => {
      this.q = new ModelQuery(Thread, this.db);
      this.m1 = Thread.attributes.id.equal(4);
      this.m2 = Thread.attributes.categories.contains('category-id');
    });

    it('should accept an array of Matcher objects', () => {
      this.q.where([this.m1, this.m2]);
      expect(this.q._matchers.length).toBe(2);
      expect(this.q._matchers[0]).toBe(this.m1);
      expect(this.q._matchers[1]).toBe(this.m2);
    });

    it('should accept a single Matcher object', () => {
      this.q.where(this.m1);
      expect(this.q._matchers.length).toBe(1);
      expect(this.q._matchers[0]).toBe(this.m1);
    });

    it('should append to any existing where clauses', () => {
      this.q.where(this.m1);
      this.q.where(this.m2);
      expect(this.q._matchers.length).toBe(2);
      expect(this.q._matchers[0]).toBe(this.m1);
      expect(this.q._matchers[1]).toBe(this.m2);
    });

    it('should accept a shorthand format', () => {
      this.q.where({ id: 4, lastMessageReceivedTimestamp: 1234 });
      expect(this.q._matchers.length).toBe(2);
      expect(this.q._matchers[0].attr.modelKey).toBe('id');
      expect(this.q._matchers[0].comparator).toBe('=');
      expect(this.q._matchers[0].val).toBe(4);
    });

    it('should return the query so it can be chained', () => {
      expect(this.q.where({ id: 4 })).toBe(this.q);
    });

    it('should immediately raise an exception if an un-queryable attribute is specified', () =>
      expect(() => {
        this.q.where({ snippet: 'My Snippet' });
      }).toThrow());

    it('should immediately raise an exception if a non-existent attribute is specified', () =>
      expect(() => {
        this.q.where({ looksLikeADuck: 'of course' });
      }).toThrow());
  });

  describe('order', () => {
    beforeEach(() => {
      this.q = new ModelQuery(Thread, this.db);
      this.o1 = Thread.attributes.lastMessageReceivedTimestamp.descending();
      this.o2 = Thread.attributes.subject.descending();
    });

    it('should accept an array of SortOrders', () => {
      this.q.order([this.o1, this.o2]);
      expect(this.q._orders.length).toBe(2);
    });

    it('should accept a single SortOrder object', () => {
      this.q.order(this.o2);
      expect(this.q._orders.length).toBe(1);
    });

    it('should extend any existing ordering', () => {
      this.q.order(this.o1);
      this.q.order(this.o2);
      expect(this.q._orders.length).toBe(2);
      expect(this.q._orders[0]).toBe(this.o1);
      expect(this.q._orders[1]).toBe(this.o2);
    });

    it('should return the query so it can be chained', () => {
      expect(this.q.order(this.o2)).toBe(this.q);
    });
  });

  describe('include', () => {
    beforeEach(() => {
      this.q = new ModelQuery(Message, this.db);
    });

    it('should throw an exception if the attribute is not a joined data attribute', () =>
      expect(() => {
        this.q.include(Message.attributes.unread);
      }).toThrow());

    it('should add the provided property to the list of joined properties', () => {
      expect(this.q._includeJoinedData).toEqual([]);
      this.q.include(Message.attributes.body);
      expect(this.q._includeJoinedData).toEqual([Message.attributes.body]);
    });
  });

  describe('includeAll', () => {
    beforeEach(() => {
      this.q = new ModelQuery(Message, this.db);
    });

    it('should add all the JoinedData attributes of the class', () => {
      expect(this.q._includeJoinedData).toEqual([]);
      this.q.includeAll();
      expect(this.q._includeJoinedData).toEqual([Message.attributes.body]);
    });
  });

  describe('response formatting', () =>
    it('should always return a Number for counts', () => {
      const q = new ModelQuery(Message, this.db);
      q.where({ accountId: 'abcd' }).count();

      const raw = [{ count: '12' }];
      expect(q.formatResult(q.inflateResult(raw))).toBe(12);
    }));

  describe('sql', () => {
    beforeEach(() => {
      this.runScenario = (klass, scenario) => {
        const q = new ModelQuery(klass, this.db);
        Attributes.Matcher.muid = 1;
        scenario.builder(q);
        expect(
          q
            .sql()
            .replace(/ /g, '')
            .trim()
        ).toBe(scenario.sql.replace(/ /g, '').trim());
      };
    });

    it('should finalize the query so no further changes can be made', () => {
      const q = new ModelQuery(Account, this.db);
      spyOn(q, 'finalize');
      q.sql();
      expect(q.finalize).toHaveBeenCalled();
    });

    it('should correctly generate queries with multiple where clauses', () => {
      this.runScenario(Account, {
        builder: q => q.where({ emailAddress: 'ben@nylas.com' }).where({ id: 2 }),
        sql:
          'SELECT `Account`.`data` FROM `Account`  ' +
          "WHERE `Account`.`emailAddress` = 'ben@nylas.com' AND `Account`.`id` = 2",
      });
    });

    it('should correctly escape single quotes with more double single quotes (LIKE)', () => {
      this.runScenario(Account, {
        builder: q => q.where(Account.attributes.emailAddress.like("you're")),
        sql:
          "SELECT `Account`.`data` FROM `Account`  WHERE `Account`.`emailAddress` like '%you''re%'",
      });
    });

    it('should correctly escape single quotes with more double single quotes (equal)', () => {
      this.runScenario(Account, {
        builder: q => q.where(Account.attributes.emailAddress.equal("you're")),
        sql: "SELECT `Account`.`data` FROM `Account`  WHERE `Account`.`emailAddress` = 'you''re'",
      });
    });

    it('should correctly generate COUNT queries', () => {
      this.runScenario(Thread, {
        builder: q => q.where({ accountId: 'abcd' }).count(),
        sql: 'SELECT COUNT(*) as count FROM `Thread`  ' + "WHERE `Thread`.`accountId` = 'abcd'  ",
      });
    });

    it('should correctly generate LIMIT 1 queries for single items', () => {
      this.runScenario(Thread, {
        builder: q => q.where({ accountId: 'abcd' }).one(),
        sql:
          'SELECT `Thread`.`data`  FROM `Thread`  ' +
          "WHERE `Thread`.`accountId` = 'abcd'  " +
          'ORDER BY `Thread`.`lastMessageReceivedTimestamp` DESC LIMIT 1',
      });
    });

    it('should correctly generate `contains` queries using JOINS', () => {
      this.runScenario(Thread, {
        builder: q =>
          q.where(Thread.attributes.categories.contains('category-id')).where({ id: '1234' }),
        sql:
          'SELECT `Thread`.`data`  FROM `Thread` ' +
          'INNER JOIN `ThreadCategory` AS `M1` ON `M1`.`id` = `Thread`.`id` ' +
          "WHERE `M1`.`value` = 'category-id' AND `Thread`.`id` = '1234'  " +
          'ORDER BY `Thread`.`lastMessageReceivedTimestamp` DESC',
      });

      this.runScenario(Thread, {
        builder: q =>
          q.where([
            Thread.attributes.categories.contains('l-1'),
            Thread.attributes.categories.contains('l-2'),
          ]),
        sql:
          'SELECT `Thread`.`data`  FROM `Thread` ' +
          'INNER JOIN `ThreadCategory` AS `M1` ON `M1`.`id` = `Thread`.`id` ' +
          'INNER JOIN `ThreadCategory` AS `M2` ON `M2`.`id` = `Thread`.`id` ' +
          "WHERE `M1`.`value` = 'l-1' AND `M2`.`value` = 'l-2'  " +
          'ORDER BY `Thread`.`lastMessageReceivedTimestamp` DESC',
      });
    });

    it("should correctly generate queries with the class's naturalSortOrder when one is available and no other orders are provided", () => {
      this.runScenario(Thread, {
        builder: q => q.where({ accountId: 'abcd' }),
        sql:
          'SELECT `Thread`.`data`  FROM `Thread`  ' +
          "WHERE `Thread`.`accountId` = 'abcd'  " +
          'ORDER BY `Thread`.`lastMessageReceivedTimestamp` DESC',
      });

      this.runScenario(Thread, {
        builder: q =>
          q
            .where({ accountId: 'abcd' })
            .order(Thread.attributes.lastMessageReceivedTimestamp.ascending()),
        sql:
          'SELECT `Thread`.`data`  FROM `Thread`  ' +
          "WHERE `Thread`.`accountId` = 'abcd'  " +
          'ORDER BY `Thread`.`lastMessageReceivedTimestamp` ASC',
      });

      this.runScenario(Account, {
        builder: q => q.where({ id: 'abcd' }),
        sql: 'SELECT `Account`.`data` FROM `Account`  ' + "WHERE `Account`.`id` = 'abcd'  ",
      });
    });

    it('should correctly generate queries requesting joined data attributes', () => {
      this.runScenario(Message, {
        builder: q => q.where({ id: '1234' }).include(Message.attributes.body),
        sql:
          "SELECT `Message`.`data`, IFNULL(`MessageBody`.`value`, '!NULLVALUE!') AS `body`  " +
          'FROM `Message` LEFT OUTER JOIN `MessageBody` ON `MessageBody`.`id` = `Message`.`id` ' +
          "WHERE `Message`.`id` = '1234'  ORDER BY `Message`.`date` ASC",
      });
    });
  });
});
