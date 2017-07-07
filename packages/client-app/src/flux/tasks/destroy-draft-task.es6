import Task from './task';
import Attributes from '../attributes';

export default class DestroyDraftTask extends Task {

  static attributes = Object.assign({}, Task.attributes, {
    headerMessageId: Attributes.String({
      modelKey: 'headerMessageId',
    }),
  });
}
