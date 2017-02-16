const Raven = require('raven');

export default Raven.config(process.env.SENTRY_DSN || "https://c88e3b7525e04b4b88d925d948686ec3:8db413d88d1a407bb8cf2f62489a4ec1@sentry.nylas.com/28").install();
