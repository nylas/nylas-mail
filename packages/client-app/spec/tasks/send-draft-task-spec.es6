import {
  APIError,
  Actions,
  AccountStore,
  DatabaseStore,
  DatabaseWriter,
  Message,
  Contact,
  Task,
  SendDraftTask,
  NylasAPI,
  NylasAPIHelpers,
  NylasAPIRequest,
  SoundRegistry,
  SyncbackMetadataTask,
} from 'nylas-exports';


const DBt = DatabaseWriter.prototype;
const withoutWhitespace = (s) => s.replace(/[\n\r\s]/g, '');

xdescribe('SendDraftTask', function sendDraftTask() {
  describe("assertDraftValidity", () => {
    it("rejects if there are still uploads on the draft", () => {
      const badTask = new SendDraftTask('1');
      badTask.draft = new Message({
        from: [new Contact({email: TEST_ACCOUNT_EMAIL})],
        accountId: TEST_ACCOUNT_ID,
        clientId: '1',
        uploads: ['123'],
      });
      badTask.assertDraftValidity().then(() => {
        throw new Error("Shouldn't succeed");
      })
      .catch((err) => {
        expect(err.message).toBe("Files have been added since you started sending this draft. Double-check the draft and click 'Send' again..");
      });
    });

    it("rejects if no from address is specified", () => {
      const badTask = new SendDraftTask('1');
      badTask.draft = new Message({from: [],
        uploads: [],
        accountId: TEST_ACCOUNT_ID,
        clientId: '1',
      })
      badTask.assertDraftValidity().then(() => {
        throw new Error("Shouldn't succeed");
      })
      .catch((err) => {
        expect(err.message).toBe("SendDraftTask - you must populate `from` before sending.");
      });
    });

    it("rejects if the from address does not map to any account", () => {
      const badTask = new SendDraftTask('1');
      badTask.draft = new Message({
        from: [new Contact({email: 'not-configuredthis.nylas.com'})],
        accountId: TEST_ACCOUNT_ID,
        clientId: '1',
      });
      badTask.assertDraftValidity().then(() => {
        throw new Error("Shouldn't succeed");
      })
      .catch((err) => {
        expect(err.message).toBe("SendDraftTask - you can only send drafts from a configured account.");
      });
    });
  });

  describe("performRemote", () => {
    beforeEach(() => {
      this.response = {
        version: 2,
        id: '1233123AEDF1',
        account_id: TEST_ACCOUNT_ID,
        from: [new Contact({email: TEST_ACCOUNT_EMAIL})],
        subject: 'New Draft',
        body: 'hello world',
        to: [new Contact({
          name: 'Dummy',
          email: 'dummythis.nylas.com',
        })],
      };

      spyOn(NylasAPIRequest.prototype, 'run').andCallFake((options) => {
        if (options.success) { options.success(this.response); }
        return Promise.resolve(this.response);
      })
      spyOn(NylasAPI, 'incrementRemoteChangeLock');
      spyOn(NylasAPI, 'decrementRemoteChangeLock');
      spyOn(NylasAPIHelpers, 'makeDraftDeletionRequest');
      spyOn(DBt, 'unpersistModel').andReturn(Promise.resolve());
      spyOn(DBt, 'persistModel').andReturn(Promise.resolve());
      spyOn(SoundRegistry, "playSound");
      spyOn(Actions, "draftDeliverySucceeded");
    });

    // The tests below are invoked twice, once with a new this.draft and one with a
    // persisted this.draft.
    const sharedTests = () => {
      it("should return Task.Status.Success", () => {
        waitsForPromise(() => {
          this.task.performLocal();
          return this.task.performRemote().then((status) => {
            expect(status).toBe(Task.Status.Success);
          });
        });
      });

      it("makes a send request with the correct data", () => {
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(NylasAPIRequest.prototype.run).toHaveBeenCalled();
          expect(NylasAPIRequest.prototype.run.callCount).toBe(1);
          const options = NylasAPIRequest.prototype.run.mostRecentCall.args[0];
          expect(options.path).toBe("/send");
          expect(options.method).toBe('POST');
          expect(options.accountId).toBe(TEST_ACCOUNT_ID);
          expect(options.body).toEqual(this.draft.toJSON());
        }));
      });

      it("should always send the draft body in the request body (joined attribute check)", () => {
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(NylasAPIRequest.prototype.run.calls.length).toBe(1);
          const options = NylasAPIRequest.prototype.run.mostRecentCall.args[0];
          expect(options.body.body).toBe('hello world');
        }));
      });

      describe("saving the sent message", () => {
        it("should preserve the draft client id", () => {
          waitsForPromise(() => this.task.performRemote().then(() => {
            expect(DBt.persistModel).toHaveBeenCalled();
            const model = DBt.persistModel.mostRecentCall.args[0];
            expect(model.clientId).toEqual(this.draft.clientId);
            expect(model.serverId).toEqual(this.response.id);
            expect(model.draft).toEqual(false);
          }));
        });

        it("should preserve metadata, but not version numbers", () => {
          waitsForPromise(() => this.task.performRemote().then(() => {
            expect(DBt.persistModel).toHaveBeenCalled();
            const model = DBt.persistModel.mostRecentCall.args[0];

            expect(model.pluginMetadata.length).toEqual(this.draft.pluginMetadata.length);

            for (const {pluginId, value} of this.draft.pluginMetadata) {
              const updated = model.metadataObjectForPluginId(pluginId);
              expect(updated.value).toEqual(value);
              expect(updated.version).toEqual(0);
            }
          }));
        });
      });

      it("should notify the draft was sent", () => {
        waitsForPromise(() => this.task.performRemote().then(() => {
          const args = Actions.draftDeliverySucceeded.calls[0].args[0];
          expect(args.message instanceof Message).toBe(true)
          expect(args.messageClientId).toBe(this.draft.clientId)
        }));
      });

      it("should queue tasks to sync back the metadata on the new message", () => {
        spyOn(Actions, 'queueTask')
        waitsForPromise(() => this.task.performRemote().then(() => {
          let metadataTasks = Actions.queueTask.calls.map((call) => call.args[0]);
          metadataTasks = metadataTasks.filter((task) => task instanceof SyncbackMetadataTask)
          expect(metadataTasks.length).toEqual(this.draft.pluginMetadata.length);
          this.draft.pluginMetadata.forEach((pluginMetadatum, idx) => {
            expect(metadataTasks[idx].clientId).toEqual(this.draft.clientId);
            expect(metadataTasks[idx].modelClassName).toEqual('Message');
            expect(metadataTasks[idx].pluginId).toEqual(pluginMetadatum.pluginId);
          });
        }));
      });

      it("should play a sound", () => {
        spyOn(NylasEnv.config, "get").andReturn(true)
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds");
          expect(SoundRegistry.playSound).toHaveBeenCalledWith("send");
        }));
      });

      it("shouldn't play a sound if the config is disabled", () => {
        spyOn(NylasEnv.config, "get").andReturn(false)
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(NylasEnv.config.get).toHaveBeenCalledWith("core.sending.sounds");
          expect(SoundRegistry.playSound).not.toHaveBeenCalled();
        }));
      });

      describe("when there are errors", () => {
        beforeEach(() => {
          spyOn(Actions, 'draftDeliveryFailed');
          jasmine.unspy(NylasAPIRequest.prototype, "run");
        });

        it("notifies of a permanent error of misc error types", () => {
          // DB error
          let thrownError = null;
          spyOn(NylasEnv, "reportError");
          jasmine.unspy(DBt, "persistModel");
          spyOn(DBt, "persistModel").andCallFake(() => {
            thrownError = new Error('db error');
            throw thrownError;
          });
          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftDeliveryFailed).toHaveBeenCalled();
            expect(NylasEnv.reportError).toHaveBeenCalled();
          }));
        });

        it("retries the task if 'Invalid message public id'", () => {
          spyOn(NylasAPIRequest.prototype, 'run').andCallFake((options) => {
            if (options.body.reply_to_message_id) {
              const err = new APIError({body: "Invalid message public id"});
              return Promise.reject(err);
            }
            if (options.success) { options.success(this.response) }
            return Promise.resolve(this.response);
          });

          this.draft.replyToMessageId = "reply-123";
          this.draft.threadId = "thread-123";
          waitsForPromise(() => {
            return this.task.performRemote(this.draft)
            .then(() => {
              expect(NylasAPIRequest.prototype.run).toHaveBeenCalled();
              expect(NylasAPIRequest.prototype.run.callCount).toEqual(2);
              const req1 = NylasAPIRequest.prototype.run.calls[0].args[0];
              const req2 = NylasAPIRequest.prototype.run.calls[1].args[0];
              expect(req1.body.reply_to_message_id).toBe("reply-123");
              expect(req1.body.thread_id).toBe("thread-123");

              expect(req2.body.reply_to_message_id).toBe(null);
              expect(req2.body.thread_id).toBe("thread-123");
            })
          });
        });

        it("retries the task if 'Invalid message public id'", () => {
          spyOn(NylasAPIRequest.prototype, 'run').andCallFake((options) => {
            if (options.body.reply_to_message_id) {
              return Promise.reject(new APIError({body: "Invalid thread"}));
            }
            if (options.success) { options.success(this.response) }
            return Promise.resolve(this.response);
          });

          this.draft.replyToMessageId = "reply-123";
          this.draft.threadId = "thread-123";
          waitsForPromise(() => this.task.performRemote(this.draft).then(() => {
            expect(NylasAPIRequest.prototype.run).toHaveBeenCalled();
            expect(NylasAPIRequest.prototype.run.callCount).toEqual(2);
            const req1 = NylasAPIRequest.prototype.run.calls[0].args[0];
            const req2 = NylasAPIRequest.prototype.run.calls[1].args[0];
            expect(req1.body.reply_to_message_id).toBe("reply-123");
            expect(req1.body.thread_id).toBe("thread-123");

            expect(req2.body.reply_to_message_id).toBe(null);
            expect(req2.body.thread_id).toBe(null);
          }));
        });

        it("notifies of a permanent error on 500 errors", () => {
          const thrownError = new APIError({statusCode: 500, body: "err"})
          spyOn(NylasEnv, "reportError");
          spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));

          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftDeliveryFailed).toHaveBeenCalled();
          }));
        });

        it("notifies us and users of a permanent error on 400 errors", () => {
          const thrownError = new APIError({statusCode: 400, body: "err"});
          spyOn(NylasEnv, "reportError");
          spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));

          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftDeliveryFailed).toHaveBeenCalled();
          }));
        });

        it("presents helpful error messages for 402 errors (security blocked)", () => {
          const thrownError = new APIError({
            statusCode: 402,
            body: {
              message: "Message content rejected for security reasons",
              server_error: "552 : 5.7.0 This message was blocked because its content presents a potential\n5.7.0 security issue. Please visit\n5.7.0  https://support.google.com/mail/answer/6590 to review our message\n5.7.0 content and attachment content guidelines. fk9sm21147314pad.9 - gsmtp",
              type: "api_error",
            },
          });

          const expectedMessage = `
            Sorry, this message could not be sent because it was rejected by your mail provider. (Message content rejected for security reasons)

            552 : 5.7.0 This message was blocked because its content presents a potential
            5.7.0 security issue. Please visit
            5.7.0  https://support.google.com/mail/answer/6590 to review our message
            5.7.0 content and attachment content guidelines. fk9sm21147314pad.9 - gsmtp
          `

          spyOn(NylasEnv, "reportError");
          spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));

          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftDeliveryFailed).toHaveBeenCalled();

            const msg = Actions.draftDeliveryFailed.calls[0].args[0].errorMessage;
            expect(withoutWhitespace(msg)).toEqual(withoutWhitespace(expectedMessage));
          }));
        });

        it("presents helpful error messages for 402 errors (recipient failed)", () => {
          const thrownError = new APIError({
            statusCode: 402,
            body: {
              message: "Sending to at least one recipient failed.",
              server_error: "<<Don't know what this looks like >>",
              type: "api_error",
            },
          })

          const expectedMessage = "This message could not be delivered to at least one recipient. (Note: other recipients may have received this message - you should check Sent Mail before re-sending this message.)"

          spyOn(NylasEnv, "reportError");
          spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));
          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftDeliveryFailed).toHaveBeenCalled();

            const msg = Actions.draftDeliveryFailed.calls[0].args[0].errorMessage;
            expect(withoutWhitespace(msg)).toEqual(withoutWhitespace(expectedMessage));
          }));
        });

        describe("checking the promise chain halts on errors", () => {
          beforeEach(() => {
            spyOn(NylasEnv, 'reportError');
            spyOn(this.task, "sendMessage").andCallThrough();
            spyOn(this.task, "onSuccess").andCallThrough();
            spyOn(this.task, "onError").andCallThrough();

            this.expectBlockedChain = () => {
              expect(this.task.sendMessage).toHaveBeenCalled();
              expect(this.task.onSuccess).not.toHaveBeenCalled();
              expect(this.task.onError).toHaveBeenCalled();
            };
          });

          it("halts on 500s", () => {
            const thrownError = new APIError({statusCode: 500, body: "err"});
            spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("halts on 400s", () => {
            const thrownError = new APIError({statusCode: 400, body: "err"});
            spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("halts and retries on not permanent error codes", () => {
            const thrownError = new APIError({statusCode: 409, body: "err"});
            spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("halts on other errors", () => {
            const thrownError = new Error("oh no");
            spyOn(NylasAPIRequest.prototype, 'run').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("doesn't halt on success", () => {
            // Don't spy reportError to make sure to fail the test on unexpected
            // errors
            jasmine.unspy(NylasEnv, 'reportError');
            spyOn(NylasAPIRequest.prototype, 'run').andCallFake((options) => {
              if (options.success) { options.success(this.response) }
              return Promise.resolve(this.response);
            });

            waitsForPromise(() => this.task.performRemote().then((status) => {
              expect(status).toBe(Task.Status.Success);
              expect(this.task.sendMessage).toHaveBeenCalled();
              expect(this.task.onSuccess).toHaveBeenCalled();
              expect(this.task.onError).not.toHaveBeenCalled();
            }));
          });
        });
      });
    };

    describe("with a new draft", () => {
      beforeEach(() => {
        this.draft = new Message({
          version: 1,
          clientId: 'client-id',
          accountId: TEST_ACCOUNT_ID,
          from: [new Contact({email: TEST_ACCOUNT_EMAIL})],
          subject: 'New Draft',
          draft: true,
          body: 'hello world',
          uploads: [],
        });

        this.draft.applyPluginMetadata('pluginIdA', {tracked: true});
        this.draft.applyPluginMetadata('pluginIdB', {a: true, b: 2});
        this.draft.metadataObjectForPluginId('pluginIdA').version = 2;

        this.task = new SendDraftTask('client-id');
        this.calledBody = "ERROR: The body wasn't included!";
        spyOn(DatabaseStore, "run").andReturn(Promise.resolve(this.draft));
      });

      sharedTests();

      it("should locally convert the draft to a message on send", () => {
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(DBt.persistModel).toHaveBeenCalled();
          const model = DBt.persistModel.calls[0].args[0];
          expect(model.clientId).toBe(this.draft.clientId);
          expect(model.serverId).toBe(this.response.id);
          expect(model.draft).toBe(false);
        }));
      });
    });

    describe("with an existing persisted draft", () => {
      beforeEach(() => {
        this.draft = new Message({
          version: 1,
          clientId: 'client-id',
          serverId: 'server-123',
          accountId: TEST_ACCOUNT_ID,
          from: [new Contact({email: TEST_ACCOUNT_EMAIL})],
          subject: 'New Draft',
          draft: true,
          body: 'hello world',
          to: [new Contact({
            name: 'Dummy',
            email: 'dummythis.nylas.com',
          })],
          uploads: [],
        });

        this.draft.applyPluginMetadata('pluginIdA', {tracked: true});
        this.draft.applyPluginMetadata('pluginIdB', {a: true, b: 2});
        this.draft.metadataObjectForPluginId('pluginIdA').version = 2;

        this.task = new SendDraftTask('client-id');
        this.calledBody = "ERROR: The body wasn't included!";
        spyOn(DatabaseStore, "run").andReturn(Promise.resolve(this.draft));
      });

      sharedTests();

      it("should call makeDraftDeletionRequest to delete the draft after sending", () => {
        this.task.performLocal();
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(NylasAPIHelpers.makeDraftDeletionRequest).toHaveBeenCalled()
        }));
      });

      it("should locally convert the existing draft to a message on send", () => {
        expect(this.draft.clientId).toBe(this.draft.clientId);
        expect(this.draft.serverId).toBe("server-123");

        this.task.performLocal();
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(DBt.persistModel).toHaveBeenCalled()
          const model = DBt.persistModel.calls[0].args[0];
          expect(model.clientId).toBe(this.draft.clientId);
          expect(model.serverId).toBe(this.response.id);
          expect(model.draft).toBe(false);
        }));
      });
    });
  });

  describe("hasCustomBodyPerRecipient", () => {
    beforeEach(() => {
      this.task = new SendDraftTask('client-id');
      this.task.allowMultiSend = true;
      this.task.draft = new Message({
        version: 1,
        clientId: 'client-id',
        serverId: 'server-123',
        accountId: TEST_ACCOUNT_ID,
        from: [new Contact({email: TEST_ACCOUNT_EMAIL})],
        subject: 'New Draft',
        draft: true,
        body: 'hello world',
        to: [new Contact({
          name: 'Dummy',
          email: 'dummythis.nylas.com',
        })],
        uploads: [],
      });
      this.task.draft.applyPluginMetadata('open-tracking', true);
      this.task.draft.applyPluginMetadata('link-tracking', true);

      this.applySpies = (customValues = {}) => {
        let value = {provider: customValues["AccountStore.accountForId"] || "gmail"}
        spyOn(AccountStore, "accountForId").andReturn(value)

        value = customValues["NylasEnv.packages.pluginIdFor"] || (name => name)
        spyOn(NylasEnv.packages, "pluginIdFor").andCallFake(value);

        value = {length: customValues["draft.participants"] || 5}
        spyOn(this.task.draft, "participants").andReturn(value);
      }
    });

    it("should return false if the provider is eas", () => {
      this.applySpies({"AccountStore.accountForId": "eas"})
      expect(this.task.hasCustomBodyPerRecipient()).toBe(false);
    });

    it("should return false if allowMultiSend is false", () => {
      this.applySpies();
      this.task.allowMultiSend = false;
      expect(this.task.hasCustomBodyPerRecipient()).toBe(false);
    });

    it("should return false if the open-tracking id is null", () => {
      const fake = (name) => {
        return name === "open-tracking" ? null : name;
      };
      this.applySpies({"NylasEnv.packages.pluginIdFor": fake});
      expect(this.task.hasCustomBodyPerRecipient()).toBe(false);
    });

    it("should return false if the link-tracking id is null", () => {
      const fake = (name) => {
        return name === "link-tracking" ? null : name;
      };
      this.applySpies({"NylasEnv.packages.pluginIdFor": fake});
      expect(this.task.hasCustomBodyPerRecipient()).toBe(false);
    });

    it("should return false if neither open-tracking nor link-tracking is on", () => {
      this.applySpies();
      this.task.draft.applyPluginMetadata('open-tracking', false);
      this.task.draft.applyPluginMetadata('link-tracking', false);
      expect(this.task.hasCustomBodyPerRecipient()).toBe(false);
    });

    it("should return true if only open-tracking is on", () => {
      this.applySpies();
      this.task.draft.applyPluginMetadata('link-tracking', false);
      expect(this.task.hasCustomBodyPerRecipient()).toBe(true);
    });

    it("should return true if only link-tracking is on", () => {
      this.applySpies();
      this.task.draft.applyPluginMetadata('open-tracking', false);
      expect(this.task.hasCustomBodyPerRecipient()).toBe(true);
    });

    it("should return false if there are too many participants", () => {
      this.applySpies({"draft.participants": 15});
      expect(this.task.hasCustomBodyPerRecipient()).toBe(false);
    });

    it("should return true otherwise", () => {
      this.applySpies();
      expect(this.task.hasCustomBodyPerRecipient()).toBe(true);
    });
  });
});
