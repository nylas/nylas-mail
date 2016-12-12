import _ from 'underscore'
import {APIError} from 'nylas-exports'

// Salesforce errors have a JSON body of the following format:
//
// error.message = [
//   {
//     message: "Some Salesforce error message."
//     errorCode: "SOME_SALESFORCE_ERROR_CODE_STRING"
//   }
// ]
export default class SalesforceAPIError extends APIError {
  constructor(args) {
    super(args);
    if (_.isArray(this.body)) {
      this.messages = _.pluck(this.body, "message")
      this.errorCodes = _.pluck(this.body, "errorCode")
      this.message = this.messages[0]
      this.errorCode = this.errorCodes[0]
    } else if (_.isString(this.body)) {
      this.messages = [this.body]
      this.errorCodes = []
      this.message = this.body
      this.errorCode = null
    } else {
      this.messages = []
      this.errorCodes = []
      this.message = "Unknown Salesforce Error"
      this.errorCode = null
    }
  }
}
