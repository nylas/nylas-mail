import Task from './task';
import DraftHelpers from '../stores/draft-helpers';

export default class BaseDraftTask extends Task {

  constructor(draft) {
    super();
    this.draft = draft;
  }
}
