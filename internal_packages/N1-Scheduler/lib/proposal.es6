import {Utils} from 'nylas-exports'

export default class Proposal {
  constructor(args = {}) {
    this.id = Utils.generateFakeServerId();
    Object.assign(this, args);

    // This field is used by edgehill-server to lookup the proposals.
    this.proposalId = this.id;
  }
}
