import {
  APIError,
  Actions,
  DatabaseStore,
  DatabaseTransaction,
  Message,
  Contact,
  Task,
  SendDraftTask,
  NylasAPI,
  SoundRegistry,
} from 'nylas-exports';

const DBt = DatabaseTransaction.prototype;
const withoutWhitespace = (s) => s.replace(/[\n\r\s]/g, '');

describe("SendDraftTask", () => {
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
        to: {
          name: 'Dummy',
          email: 'dummythis.nylas.com',
        },
      };

      spyOn(NylasAPI, 'makeRequest').andCallFake((options) => {
        if (options.success) { options.success(this.response); }
        return Promise.resolve(this.response);
      })
      spyOn(NylasAPI, 'incrementRemoteChangeLock');
      spyOn(NylasAPI, 'decrementRemoteChangeLock');
      spyOn(NylasAPI, 'makeDraftDeletionRequest');
      spyOn(DBt, 'unpersistModel').andReturn(Promise.resolve());
      spyOn(DBt, 'persistModel').andReturn(Promise.resolve());
      spyOn(SoundRegistry, "playSound");
      spyOn(Actions, "postNotification");
      spyOn(Actions, "sendDraftSuccess");
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
          expect(NylasAPI.makeRequest).toHaveBeenCalled();
          expect(NylasAPI.makeRequest.callCount).toBe(1);
          const options = NylasAPI.makeRequest.mostRecentCall.args[0];
          expect(options.path).toBe("/send");
          expect(options.method).toBe('POST');
          expect(options.accountId).toBe(TEST_ACCOUNT_ID);
          expect(options.body).toEqual(this.draft.toJSON());
        }));
      });

      it("should pass returnsModel:false", () => {
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(NylasAPI.makeRequest.calls.length).toBe(1);
          const options = NylasAPI.makeRequest.mostRecentCall.args[0];
          expect(options.returnsModel).toBe(false);
        }));
      });

      it("should always send the draft body in the request body (joined attribute check)", () => {
        waitsForPromise(() => this.task.performRemote().then(() => {
          expect(NylasAPI.makeRequest.calls.length).toBe(1);
          const options = NylasAPI.makeRequest.mostRecentCall.args[0];
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
          const args = Actions.sendDraftSuccess.calls[0].args[0];
          expect(args.message instanceof Message).toBe(true)
          expect(args.messageClientId).toBe(this.draft.clientId)
        }));
      });

      it("should queue tasks to sync back the metadata on the new message", () => {
        spyOn(Actions, 'queueTask')
        waitsForPromise(() => this.task.performRemote().then(() => {
          const metadataTasks = Actions.queueTask.calls.map((call) => call.args[0]);
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
          spyOn(Actions, 'draftSendingFailed');
          jasmine.unspy(NylasAPI, "makeRequest");
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
            expect(Actions.draftSendingFailed).toHaveBeenCalled();
            expect(NylasEnv.reportError).toHaveBeenCalled();
          }));
        });

        it("retries the task if 'Invalid message public id'", () => {
          spyOn(NylasAPI, 'makeRequest').andCallFake((options) => {
            if (options.body.reply_to_message_id) {
              const err = new APIError({body: "Invalid message public id"});
              return Promise.reject(err);
            } else {
              if (options.success) { options.success(this.response) }
              return Promise.resolve(this.response);
            }
          });

          this.draft.replyToMessageId = "reply-123";
          this.draft.threadId = "thread-123";
          waitsForPromise(() => this.task.performRemote(this.draft).then(() => {
            expect(NylasAPI.makeRequest).toHaveBeenCalled();
            expect(NylasAPI.makeRequest.callCount).toEqual(2);
            const req1 = NylasAPI.makeRequest.calls[0].args[0];
            const req2 = NylasAPI.makeRequest.calls[1].args[0];
            expect(req1.body.reply_to_message_id).toBe("reply-123");
            expect(req1.body.thread_id).toBe("thread-123");

            expect(req2.body.reply_to_message_id).toBe(null);
            expect(req2.body.thread_id).toBe("thread-123");
          }));
        });

        it("retries the task if 'Invalid message public id'", () => {
          spyOn(NylasAPI, 'makeRequest').andCallFake((options) => {
            if (options.body.reply_to_message_id) {
              return Promise.reject(new APIError({body: "Invalid thread"}));
            } else {
              if (options.success) { options.success(this.response) }
              return Promise.resolve(this.response);
            }
          });

          this.draft.replyToMessageId = "reply-123";
          this.draft.threadId = "thread-123";
          waitsForPromise(() => this.task.performRemote(this.draft).then(() => {
            expect(NylasAPI.makeRequest).toHaveBeenCalled();
            expect(NylasAPI.makeRequest.callCount).toEqual(2);
            const req1 = NylasAPI.makeRequest.calls[0].args[0];
            const req2 = NylasAPI.makeRequest.calls[1].args[0];
            expect(req1.body.reply_to_message_id).toBe("reply-123");
            expect(req1.body.thread_id).toBe("thread-123");

            expect(req2.body.reply_to_message_id).toBe(null);
            expect(req2.body.thread_id).toBe(null);
          }));
        });

        it("notifies of a permanent error on 500 errors", () => {
          const thrownError = new APIError({statusCode: 500, body: "err"})
          spyOn(NylasEnv, "reportError");
          spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));

          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftSendingFailed).toHaveBeenCalled();
          }));
        });

        it("notifies us and users of a permanent error on 400 errors", () => {
          const thrownError = new APIError({statusCode: 400, body: "err"});
          spyOn(NylasEnv, "reportError");
          spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));

          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftSendingFailed).toHaveBeenCalled();
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
          spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));

          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftSendingFailed).toHaveBeenCalled();

            const msg = Actions.draftSendingFailed.calls[0].args[0].errorMessage;
            expect(withoutWhitespace(msg)).toEqual(withoutWhitespace(expectedMessage));
          }));
        });

        it("presents helpful error messages for 402 errors (recipient failed)", () => {
          const thrownError = new APIError({
            statusCode: 402,
            body: {
              message: "Sending to at least one recipient failed.",
              server_error: "<<Don't know what this looks like >>",
              type: "api_error"
            },
          })

          const expectedMessage = "This message could not be delivered to at least one recipient. (Note: other recipients may have received this message - you should check Sent Mail before re-sending this message.)"

          spyOn(NylasEnv, "reportError");
          spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));
          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status[0]).toBe(Task.Status.Failed);
            expect(status[1]).toBe(thrownError);
            expect(Actions.draftSendingFailed).toHaveBeenCalled();

            const msg = Actions.draftSendingFailed.calls[0].args[0].errorMessage;
            expect(withoutWhitespace(msg)).toEqual(withoutWhitespace(expectedMessage));
          }));
        });

        it("retries on timeouts", () => {
          const thrownError = new APIError({statusCode: NylasAPI.TimeoutErrorCodes[0], body: "err"});
          spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));

          waitsForPromise(() => this.task.performRemote().then((status) => {
            expect(status).toBe(Task.Status.Retry);
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
            spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("halts on 400s", () => {
            const thrownError = new APIError({statusCode: 400, body: "err"});
            spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("halts and retries on not permanent error codes", () => {
            const thrownError = new APIError({statusCode: 409, body: "err"});
            spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("halts on other errors", () => {
            const thrownError = new Error("oh no");
            spyOn(NylasAPI, 'makeRequest').andReturn(Promise.reject(thrownError));
            waitsForPromise(() => this.task.performRemote().then(() =>
              this.expectBlockedChain()
            ))
          });

          it("doesn't halt on success", () => {
            // Don't spy reportError to make sure to fail the test on unexpected
            // errors
            jasmine.unspy(NylasEnv, 'reportError');
            spyOn(NylasAPI, 'makeRequest').andCallFake((options) => {
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
          to: {
            name: 'Dummy',
            email: 'dummythis.nylas.com',
          },
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
          expect(NylasAPI.makeDraftDeletionRequest).toHaveBeenCalled()
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
});
