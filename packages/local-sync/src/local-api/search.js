const request = require('request');
const _ = require('underscore');

class GmailSearchClient {
  constructor(accountToken) {
    this.accountToken = accountToken;
  }

  // Note that the Gmail API returns message IDs in hex format. So for
  // example the IMAP X-GM-MSGID 1438297078380071706 corresponds to
  // 13f5db9286538b1a in API responses. Normally we could just use parseInt(id, 16),
  // but many of the IDs returned are outside of the precise range of doubles,
  // so this function accomplishes hex ID parsing using rudimentary arbitrary
  // precision ints implemented using strings.
  _parseHexId(hexId) {
    const add = (a, b) => {
      let carry = 0;
      const x = a.split('').map(Number);
      const y = b.split('').map(Number);
      const result = [];
      while (x.length || y.length) {
        const sum = (x.pop() || 0) + (y.pop() || 0) + carry;
        result.push(sum < 10 ? sum : sum - 10);
        carry = sum < 10 ? 0 : 1;
      }
      if (carry) {
        result.push(carry);
      }
      result.reverse();
      return result.join('');
    };

    let value = '0';
    for (const c of hexId) {
      const digit = parseInt(c, 16);
      for (let mask = 0x8; mask; mask >>= 1) {
        value = add(value, value);
        if (digit & mask) {
          value = add(value, '1');
        }
      }
    }
    return value;
  }

  _search(query, limit) {
    let results = [];
    const params = {q: query, maxResults: limit};

    return new Promise((resolve, reject) => {
      const maxTries = 10;
      const trySearch = (numTries) => {
        if (numTries >= maxTries) {
          // If we've been through the loop 10 times, it means we got a request
          // a crazy-high offset --- raise an error.
          console.error('Too many results:', results.length);
          reject(new Error('Too many results'));
          return;
        }

        request('https://www.googleapis.com/gmail/v1/users/me/messages', {
          qs: params,
          headers: {Authorization: `Bearer ${this.accountToken}`},
        }, (error, response, body) => {
          if (error) {
            reject(new Error(`Error issuing search request: ${error}`));
            return;
          }

          if (response.statusCode !== 200) {
            reject(new Error(`Error issuing search request: ${response.statusMessage}`));
            return;
          }

          let data = null;
          try {
            data = JSON.parse(body);
          } catch (e) {
            reject(new Error(`Error parsing response as JSON: ${e}`));
            return;
          }
          if (!data.messages) {
            resolve(results);
            return;
          }

          // Note that the Gmail API returns message IDs in hex format. So for
          // example the IMAP X-GM-MSGID 1438297078380071706 corresponds to
          // 13f5db9286538b1a in the API response we have here.
          results = results.concat(data.messages.map((m) => this._parseHexId(m.id)));

          if (results.length >= limit) {
            resolve(results.slice(0, limit));
            return;
          }

          if (!data.nextPageToken) {
            resolve(results);
            return;
          }
          params.pageToken = data.nextPageToken;
          trySearch(numTries + 1);
        });
      };
      trySearch(0);
    });
  }

  async searchThreads(db, query, limit) {
    const messageIds = await this._search(query, limit);
    if (!messageIds.length) {
      return [];
    }

    const {Message, Folder, Label, Thread} = db;
    const messages = await Message.findAll({
      where: {gMsgId: {$in: messageIds}},
    });

    const threadIds = _.uniq(messages.map((m) => m.threadId));
    const threads = await Thread.findAll({
      where: {id: threadIds},
      include: [
        {model: Folder},
        {model: Label},
        {
          model: Message,
          as: 'messages',
          attributes: _.without(Object.keys(Message.attributes), 'body'),
          include: [
            {model: Folder},
          ],
        },
      ],
      limit: limit,
      order: [['lastMessageReceivedDate', 'DESC']],
    });
    return threads;
  }
}

module.exports.searchClientForAccount = (account) => {
  switch (account.provider) {
    case 'gmail': {
      const credentials = account.decryptedCredentials();
      const accountToken = account.bearerToken(credentials.xoauth2);
      return new GmailSearchClient(accountToken);
    }
    default: {
      throw new Error(`Unsupported provider for search endpoint: ${account.provider}`);
    }
  }
};
