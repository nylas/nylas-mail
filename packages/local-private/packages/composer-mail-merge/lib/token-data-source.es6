import _ from 'underscore'
import {Utils} from 'nylas-exports'


class FieldTokens {

  constructor(field, tokens = {}) {
    this._field = field
    this._tokens = tokens
  }

  linkToken(colProps) {
    const tokenId = colProps.tokenId ? colProps.tokenId : Utils.generateTempId()
    return new FieldTokens(this._field, {
      ...this._tokens,
      [tokenId]: {...colProps, field: this._field, tokenId},
    })
  }

  unlinkToken(tokenId) {
    const nextTokens = {...this._tokens}
    delete nextTokens[tokenId]
    return new FieldTokens(this._field, nextTokens)
  }

  updateToken(tokenId, props) {
    const token = this._tokens[tokenId]
    return new FieldTokens(this._field, {
      ...this._tokens,
      [tokenId]: {...token, ...props},
    })
  }

  tokens() {
    return _.values(this._tokens)
  }

  findTokens(matcher) {
    return _.where(this.tokens(), matcher)
  }

  getToken(tokenId) {
    return this._tokens[tokenId]
  }
}

class TokenDataSource {

  static fromJSON(json) {
    return json.reduce((dataSource, token) => {
      const {field, ...props} = token
      return dataSource.linkToken(field, props)
    }, new TokenDataSource())
  }

  constructor(linkedTokensByField = {}) {
    this._linkedTokensByField = linkedTokensByField
  }

  findTokens(field, matcher) {
    if (!this._linkedTokensByField[field]) { return [] }
    return this._linkedTokensByField[field].findTokens(matcher)
  }

  tokensForField(field) {
    if (!this._linkedTokensByField[field]) { return [] }
    return this._linkedTokensByField[field].tokens()
  }

  getToken(field, tokenId) {
    if (!this._linkedTokensByField[field]) { return null }
    return this._linkedTokensByField[field].getToken(tokenId)
  }

  linkToken(field, props) {
    if (!this._linkedTokensByField[field]) {
      this._linkedTokensByField[field] = new FieldTokens(field)
    }

    const current = this._linkedTokensByField[field]
    return new TokenDataSource({
      ...this._linkedTokensByField,
      [field]: current.linkToken(props),
    })
  }

  unlinkToken(field, tokenId) {
    if (!this._linkedTokensByField[field]) { return this }

    const current = this._linkedTokensByField[field]
    return new TokenDataSource({
      ...this._linkedTokensByField,
      [field]: current.unlinkToken(tokenId),
    })
  }

  updateToken(field, tokenId, props) {
    if (!this._linkedTokensByField[field]) { return this }

    const current = this._linkedTokensByField[field]
    return new TokenDataSource({
      ...this._linkedTokensByField,
      [field]: current.updateToken(tokenId, props),
    })
  }

  toJSON() {
    return Object.keys(this._linkedTokensByField)
    .map((field) => this._linkedTokensByField[field])
    .reduce((prevTokens, dataSource) => prevTokens.concat(dataSource.tokens()), [])
  }
}

export default TokenDataSource
