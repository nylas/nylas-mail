import _ from 'underscore'
import moment from 'moment-timezone'
import {DatabaseConnector} from 'cloud-core';

require('moment-round')

export default function registerAdminRoutes(server) {
  server.route({
    method: "GET",
    path: "/admin",
    config: {
      auth: "static-password",
    },
    handler: async (request, reply) => {
      const tz = request.query.tz || "America/Los_Angeles";
      const now = moment().tz(tz);
      let from = moment().tz(tz).subtract(5, 'days').floor(1, 'hours');
      if (request.query.from) from = moment.tz(request.query.from, tz).floor(1, 'hours');
      let to = moment().tz(tz).ceil(1, 'hours');
      if (request.query.to) to = moment.tz(request.query.to, tz).ceil(1, 'hours');
      let step = 1;
      if (request.query.step) step = +(request.query.step);
      const stepUnit = request.query.stepUnit || 'hour'

      const db = await DatabaseConnector.forShared();
      const TYPES = [
        {typeId: "thread-snooze", typeName: "Snooze"},
        {typeId: "n1-send-later", typeName: "Send Later"},
        {typeId: "send-reminders", typeName: "Reminders"},
      ]
      const jobData = []
      for (const {typeId, typeName} of TYPES) {
        const jobs = await db.CloudJob.findAll({
          limit: 5000,
          order: 'statusUpdatedAt DESC',
          where: {
            type: typeId,
            statusUpdatedAt: {
              $gt: from.toDate(),
            },
          },
        })

        const allHourBins = [];

        const i = moment(from).tz(tz);
        while (i.isSameOrBefore(to) && i.isSameOrBefore(now)) {
          allHourBins.push({
            start: i.valueOf(),
            dayStr: i.format("ddd, MMM Do"),
            timeStr: i.format("HH"),
            jobs: [],
          })
          i.add(step, stepUnit);
        }

        for (const job of jobs) {
          const jobDate = job.statusUpdatedAt.valueOf();
          for (const bin of allHourBins) {
            if (jobDate <= bin.start) {
              bin.jobs.push(job);
              break;
            }
          }
        }

        const grouped = _.groupBy(allHourBins, "dayStr");
        const dayBins = [];
        for (const dayStr of Object.keys(grouped)) {
          dayBins.push({dayStr: dayStr, hourBins: grouped[dayStr]})
        }
        jobData.push({
          typeId: typeId,
          typeName: typeName,
          dayBins: dayBins,
        })
      }
      reply.view('admin', {jobData});
    },
  })
}
