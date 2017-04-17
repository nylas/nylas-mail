import Interruptible from '../../src/shared/interruptible'

describe("Interruptible", () => {
  describe("when interrupted with forceReject", () => {
    it("the run method rejects immediately", async () => {
      function* neverResolves() {
        yield new Promise(() => {})
      }
      const interruptible = new Interruptible()
      const promise = interruptible.run(neverResolves)
      interruptible.interrupt({forceReject: true})
      try {
        await promise;
      } catch (err) {
        expect(/interrupted/i.test(err.toString())).toEqual(true)
      }
      // The promse never resolves, so if it doesn't reject,
      // this test will timeout.
    })
  })
})
