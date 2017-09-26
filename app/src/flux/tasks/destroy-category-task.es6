import Task from './task';
import Attributes from '../attributes';

export default class DestroyCategoryTask extends Task {
  static attributes = Object.assign({}, Task.attributes, {
    path: Attributes.String({
      modelKey: 'path',
    }),
  });

  label() {
    return `Deleting ${this.category.displayType()} ${this.category.displayName}`;
  }
}
