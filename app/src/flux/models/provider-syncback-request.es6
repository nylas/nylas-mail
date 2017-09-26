import Model from './model';
import Attributes from '../attributes';

export default class ProviderSyncbackRequest extends Model {
  static attributes = Object.assign({}, Model.attributes, {
    type: Attributes.String({
      queryable: true,
      modelKey: 'type',
    }),

    error: Attributes.Object({
      modelKey: 'error',
    }),

    props: Attributes.Object({
      modelKey: 'props',
    }),

    responseJSON: Attributes.Object({
      modelKey: 'responseJSON',
      jsonKey: 'response_json',
    }),

    // The following are "normalized" fields that we can use to consolidate
    // various thirdPartyData source. These list of attributes should
    // always be optional and may change as the needs of a Nylas contact
    // change over time.
    status: Attributes.String({
      modelKey: 'status',
    }),
  });
}
