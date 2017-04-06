import {DatabaseConnector} from 'cloud-core'
import registerMetadataRoutes from '../src/routes/metadata'
import Sentry from '../src/sentry'
import {getMockServer} from './helpers'

describe("Metadata route", () => {
  beforeEach(async function beforeEach() {
    this.server = getMockServer()
    registerMetadataRoutes(this.server)
    const {Account} = await DatabaseConnector.forShared()
    const account = await Account.create({id: 'test-account'})

    const upsertPath = '/metadata/{objectId}/{pluginId}'
    this.upsertRoute = this.server.routes.find(route => route.path === upsertPath)
    this.baseRequest = {
      auth: {
        credentials: { account },
      },
      payload: {
        version: 0,
        objectType: 'message',
        value: `{"key": "value"}`,
      },
      params: {
        pluginId: 'test-plugin',
        objectId: '129387',
      },
    }
  })

  it("creates new metadata", async function it() {
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(this.baseRequest, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error).toBeUndefined()

    const {Metadata} = await DatabaseConnector.forShared()
    const metadata = await Metadata.findAll();
    expect(metadata.length).toEqual(1)
    expect(metadata[0].pluginId).toEqual('test-plugin')
    expect(metadata[0].objectId).toEqual('129387')
    expect(metadata[0].value).toEqual({key: 'value'})
  })

  it("updates existing metadata", async function it() {
    const {Metadata} = await DatabaseConnector.forShared()
    Metadata.create({
      accountId: this.baseRequest.auth.credentials.account.id,
      pluginId: this.baseRequest.params.pluginId,
      objectId: this.baseRequest.params.objectId,
      objectType: this.baseRequest.payload.objectType,
      value: {foo: "bar"},
    })
    const prevMetadata = await Metadata.findAll()
    expect(prevMetadata.length).toEqual(1)

    const request = Object.assign({}, this.baseRequest)
    request.payload.version = 1
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(request, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error).toBeUndefined()

    const afterMetadata = await Metadata.findAll();
    expect(afterMetadata.length).toEqual(1)
    expect(afterMetadata[0].pluginId).toEqual('test-plugin')
    expect(afterMetadata[0].objectId).toEqual('129387')
    expect(afterMetadata[0].value).toEqual({key: 'value'})
  })

  it("returns error for bad `value`", async function it() {
    const request = Object.assign({}, this.baseRequest)
    request.payload.value = 'non-json string'
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(this.baseRequest, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error.includes("Invalid Request")).toEqual(true)
  })

  it("returns error for bad `expiration`", async function it() {
    const request = Object.assign({}, this.baseRequest)
    request.payload.value = '{"expiration": "this is not a date"}'
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(this.baseRequest, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error.includes("Invalid Request")).toEqual(true)
  })

  it("updates equivalent thread metadata", async function it() {
    const {Metadata} = await DatabaseConnector.forShared()
    Metadata.create({
      accountId: this.baseRequest.auth.credentials.account.id,
      pluginId: this.baseRequest.params.pluginId,
      objectId: 't:1',
      objectType: 'thread',
      value: {foo: "bar"},
    })
    const prevMetadata = await Metadata.findAll()
    expect(prevMetadata.length).toEqual(1)

    const request = Object.assign({}, this.baseRequest)
    request.params.objectId = 't:7'
    request.payload.objectType = 'thread'
    request.payload.messageIds = ['1', '7']
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(request, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error).toBeUndefined()

    const afterMetadata = await Metadata.findAll();
    expect(afterMetadata.length).toEqual(1)
    expect(afterMetadata[0].pluginId).toEqual('test-plugin')
    expect(afterMetadata[0].objectId).toEqual('t:1')
    expect(afterMetadata[0].value).toEqual({key: 'value'})
  })

  it("doesn't update non-equivalent thread metadata", async function it() {
    const {Metadata} = await DatabaseConnector.forShared()
    Metadata.create({
      accountId: this.baseRequest.auth.credentials.account.id,
      pluginId: this.baseRequest.params.pluginId,
      objectId: 't:1',
      objectType: 'thread',
      value: {foo: "bar"},
    })
    const prevMetadata = await Metadata.findAll()
    expect(prevMetadata.length).toEqual(1)

    const request = Object.assign({}, this.baseRequest)
    request.params.objectId = 't:7'
    request.payload.objectType = 'thread'
    request.payload.messageIds = ['5', '7']
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(request, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error).toBeUndefined()

    const afterMetadata = await Metadata.findAll();
    expect(afterMetadata.length).toEqual(2)
    expect(afterMetadata[0].pluginId).toEqual('test-plugin')
    expect(afterMetadata[0].objectId).toEqual('t:1')
    expect(afterMetadata[0].value).toEqual({foo: 'bar'})
  })

  it("doesn't merge equivalent threads with different plugin ids", async function it() {
    const {Metadata} = await DatabaseConnector.forShared()
    Metadata.create({
      accountId: this.baseRequest.auth.credentials.account.id,
      pluginId: 'other-plugin',
      objectId: 't:1',
      objectType: 'thread',
      value: {foo: "bar"},
    })
    const prevMetadata = await Metadata.findAll()
    expect(prevMetadata.length).toEqual(1)

    const request = Object.assign({}, this.baseRequest)
    request.params.objectId = 't:1'
    request.payload.objectType = 'thread'
    request.payload.messageIds = ['1']
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(request, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error).toBeUndefined()

    const afterMetadata = await Metadata.findAll();
    expect(afterMetadata.length).toEqual(2)
    expect(afterMetadata[0].pluginId).toEqual('other-plugin')
    expect(afterMetadata[0].objectId).toEqual('t:1')
    expect(afterMetadata[0].value).toEqual({foo: 'bar'})
  })

  it("reconciles thread metadata when it receives a missing message link",
    async function it() {
      const {Metadata} = await DatabaseConnector.forShared()
      Metadata.create({
        accountId: this.baseRequest.auth.credentials.account.id,
        pluginId: this.baseRequest.params.pluginId,
        objectId: 't:1',
        objectType: 'thread',
        value: {foo: "bar"},
      })
      Metadata.create({
        accountId: this.baseRequest.auth.credentials.account.id,
        pluginId: this.baseRequest.params.pluginId,
        objectId: 't:4',
        objectType: 'thread',
        value: {hello: "world"},
      })
      const prevMetadata = await Metadata.findAll()
      expect(prevMetadata.length).toEqual(2)

      const request = Object.assign({}, this.baseRequest)
      request.params.objectId = 't:7'
      request.payload.objectType = 'thread'
      request.payload.messageIds = ['1', '4', '7']
      const reply = await new Promise((resolve, reject) => {
        try {
          this.upsertRoute.handler(request, resolve)
        } catch (error) {
          reject(error)
        }
      })
      expect(reply.error).toBeUndefined()

      const afterMetadata = await Metadata.findAll();
      expect(afterMetadata.length).toEqual(1)
      expect(afterMetadata[0].pluginId).toEqual('test-plugin')
      expect(afterMetadata[0].objectId).toEqual('t:1')
      expect(afterMetadata[0].value).toEqual({key: 'value', foo: 'bar', hello: 'world'})
    }
  )

  // "right" means values from all equivalent metadata, and the latest value if
  // there's a key conflict. Also tests that sentry is called if there is a key
  // conflict
  it("uses the right values when reconciling threads", async function it() {
    spyOn(Sentry, "captureException")

    const {Metadata} = await DatabaseConnector.forShared()
    await Metadata.create({
      accountId: this.baseRequest.auth.credentials.account.id,
      pluginId: this.baseRequest.params.pluginId,
      objectId: 't:1',
      objectType: 'thread',
      value: {foo: "bar", some: 'thing'},
    })
    await Metadata.create({
      accountId: this.baseRequest.auth.credentials.account.id,
      pluginId: this.baseRequest.params.pluginId,
      objectId: 't:4',
      objectType: 'thread',
      value: {foo: "baz", other: 'thing'},
    })
    await Metadata.create({
      accountId: this.baseRequest.auth.credentials.account.id,
      pluginId: this.baseRequest.params.pluginId,
      objectId: 't:11',
      objectType: 'thread',
      value: {foo: "boom", hello: 'world'},
    })
    const prevMetadata = await Metadata.findAll()
    expect(prevMetadata.length).toEqual(3)

    const request = Object.assign({}, this.baseRequest)
    request.params.objectId = 't:7'
    request.payload.objectType = 'thread'
    request.payload.messageIds = ['1', '4', '7', '11']
    const reply = await new Promise((resolve, reject) => {
      try {
        this.upsertRoute.handler(request, resolve)
      } catch (error) {
        reject(error)
      }
    })
    expect(reply.error).toBeUndefined()
    expect(Sentry.captureException).toHaveBeenCalled()

    const afterMetadata = await Metadata.findAll();
    expect(afterMetadata.length).toEqual(1)
    expect(afterMetadata[0].pluginId).toEqual('test-plugin')
    expect(afterMetadata[0].objectId).toEqual('t:1')
    expect(afterMetadata[0].value).toEqual({
      key: 'value',
      foo: 'boom',
      some: 'thing',
      other: 'thing',
      hello: 'world',
    })
  })

  describe("off-by-one metadata versions", function describe() {
    it("merges if data is only added, not changed", async function it() {
      const {Metadata} = await DatabaseConnector.forShared()
      Metadata.create({
        accountId: this.baseRequest.auth.credentials.account.id,
        pluginId: this.baseRequest.params.pluginId,
        objectId: this.baseRequest.params.objectId,
        objectType: this.baseRequest.payload.objectType,
        value: {key: "value"},
        version: 1,
      })
      const prevMetadata = await Metadata.findAll()
      expect(prevMetadata.length).toEqual(1)

      const request = Object.assign({}, this.baseRequest)
      request.payload.value = `{"key": "value", "foo": "bar"}`
      request.payload.version = 0
      const reply = await new Promise((resolve, reject) => {
        try {
          this.upsertRoute.handler(request, resolve)
        } catch (error) {
          reject(error)
        }
      })
      expect(reply.error).toBeUndefined()

      const afterMetadata = await Metadata.findAll();
      expect(afterMetadata.length).toEqual(1)
      expect(afterMetadata[0].pluginId).toEqual('test-plugin')
      expect(afterMetadata[0].objectId).toEqual('129387')
      expect(afterMetadata[0].value).toEqual({key: 'value', foo: 'bar'})
    })

    it("errors if entries have changed", async function it() {
      const {Metadata} = await DatabaseConnector.forShared()
      Metadata.create({
        accountId: this.baseRequest.auth.credentials.account.id,
        pluginId: this.baseRequest.params.pluginId,
        objectId: this.baseRequest.params.objectId,
        objectType: this.baseRequest.payload.objectType,
        value: {key: "value"},
        version: 1,
      })
      const prevMetadata = await Metadata.findAll()
      expect(prevMetadata.length).toEqual(1)

      const request = Object.assign({}, this.baseRequest)
      request.payload.value = `{"key": "changedValue"}`
      request.payload.version = 0
      const reply = await new Promise((resolve, reject) => {
        try {
          this.upsertRoute.handler(request, resolve)
        } catch (error) {
          reject(error)
        }
      })
      expect(/version conflict/i.test(reply.error)).toEqual(true)

      const afterMetadata = await Metadata.findAll();
      expect(afterMetadata.length).toEqual(1)
      expect(afterMetadata[0].pluginId).toEqual('test-plugin')
      expect(afterMetadata[0].objectId).toEqual('129387')
      expect(afterMetadata[0].value).toEqual({key: 'value'})
    })
  })
})
