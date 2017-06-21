import Model from './model';
import Query from './query';
import Attributes from '../attributes';

class JSONBlobQuery extends Query {
  formatResult(objects) {
    return objects[0] ? objects[0].json : null;
  }
}

export default class JSONBlob extends Model {
  static Query = JSONBlobQuery;

  static attributes = {
    id: Attributes.String({
      queryable: true,
      modelKey: 'id',
    }),

    json: Attributes.Object({
      modelKey: 'json',
      jsonKey: 'json',
    }),
  };

  get key() {
    return this.id;
  }

  set key(val) {
    this.id = val;
  }
}
