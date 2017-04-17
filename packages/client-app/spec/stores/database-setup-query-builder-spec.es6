/* eslint quote-props: 0 */
import TestModel from '../fixtures/db-test-model';
import Attributes from '../../src/flux/attributes';
import DatabaseSetupQueryBuilder from '../../src/flux/stores/database-setup-query-builder';

xdescribe("DatabaseSetupQueryBuilder", function DatabaseSetupQueryBuilderSpecs() {
  beforeEach(() => {
    this.builder = new DatabaseSetupQueryBuilder();
  });

  describe("setupQueriesForTable", () => {
    it("should return the queries for creating the table and the primary unique index", () => {
      TestModel.attributes = {
        'attrQueryable': Attributes.DateTime({
          queryable: true,
          modelKey: 'attrQueryable',
          jsonKey: 'attr_queryable',
        }),

        'attrNonQueryable': Attributes.Collection({
          modelKey: 'attrNonQueryable',
          jsonKey: 'attr_non_queryable',
        }),
      };
      const queries = this.builder.setupQueriesForTable(TestModel);
      const expected = [
        'CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB,attr_queryable INTEGER)',
        'CREATE UNIQUE INDEX IF NOT EXISTS `TestModel_id` ON `TestModel` (`id`)',
      ];
      queries.map((query, i) =>
        expect(query).toBe(expected[i])
      );
    });

    it("should correctly create join tables for models that have queryable collections", () => {
      TestModel.configureWithCollectionAttribute();
      const queries = this.builder.setupQueriesForTable(TestModel);
      const expected = [
        'CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB,client_id TEXT,server_id TEXT,other TEXT)',
        'CREATE UNIQUE INDEX IF NOT EXISTS `TestModel_id` ON `TestModel` (`id`)',
        'CREATE TABLE IF NOT EXISTS `TestModelCategory` (id TEXT KEY,`value` TEXT,other TEXT)',
        'CREATE INDEX IF NOT EXISTS `TestModelCategory_id` ON `TestModelCategory` (`id` ASC)',
        'CREATE UNIQUE INDEX IF NOT EXISTS `TestModelCategory_val_id` ON `TestModelCategory` (`value` ASC, `id` ASC)',
      ];
      queries.map((query, i) =>
        expect(query).toBe(expected[i])
      );
    });

    it("should use the correct column type for each attribute", () => {
      TestModel.configureWithAllAttributes();
      const queries = this.builder.setupQueriesForTable(TestModel);
      expect(queries[0]).toBe('CREATE TABLE IF NOT EXISTS `TestModel` (id TEXT PRIMARY KEY,data BLOB,datetime INTEGER,string-json-key TEXT,boolean INTEGER,number INTEGER)');
    });

    describe("when the model provides additional sqlite config", () => {
      it("the setup method should return these queries", () => {
        TestModel.configureWithAdditionalSQLiteConfig();
        spyOn(TestModel.additionalSQLiteConfig, 'setup').andCallThrough();
        const queries = this.builder.setupQueriesForTable(TestModel);
        expect(TestModel.additionalSQLiteConfig.setup).toHaveBeenCalledWith();
        expect(queries.pop()).toBe('CREATE INDEX IF NOT EXISTS ThreadListIndex ON Thread(last_message_received_timestamp DESC, account_id, id)');
      });

      it("should not fail if additional config is present, but setup is undefined", () => {
        delete TestModel.additionalSQLiteConfig.setup;
        this.m = new TestModel({id: 'local-6806434c-b0cd', body: 'hello world'});
        expect(() => this.builder.setupQueriesForTable(TestModel)).not.toThrow();
      });
    });
  });
});
