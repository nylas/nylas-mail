# Cloud Workers

This is a Cloud worker service for Nylas Mail. It provides background workers
to process features such as Reminders, Snooze, and Send Later. It is heavily
reliant on the Metadata services exposed by Cloud API.

For details on how to run Cloud Workers, see the
[cloud-core/README.md](https://github.com/nylas/nylas-mail-all/blob/master/packages/cloud-core/README.md)
and run `npm run start-cloud` from the root of the repository.