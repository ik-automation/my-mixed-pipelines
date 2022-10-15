local basic = import 'grafana/basic.libsonnet';

local longPollingRequestStateCounter =
  basic.timeseries(
    'Workhorse long polling - request statuses',
    legendFormat='{{status}}',
    format='short',
    stack=true,
    fill=1,
    query=|||
      sum by (status) (
        increase(gitlab_workhorse_builds_register_handler_requests{environment=~"$environment",stage=~"$stage"}[$__interval])
      )
    |||,
  );

local longPollingOpenRequests =
  basic.timeseries(
    'Workhorse long polling - open requests',
    legendFormat='{{state}}',
    format='short',
    stack=true,
    fill=1,
    query=|||
      sum by (state) (
        gitlab_workhorse_builds_register_handler_open{environment=~"$environment",stage=~"$stage"}
      )
    |||,
  );

local queueingErrors =
  basic.timeseries(
    'Workhorse queueing errors',
    legendFormat='{{type}}',
    format='ops',
    query=|||
      sum by (type) (
        increase(
          gitlab_workhorse_queueing_errors{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}[$__interval]
        )
      )
    |||,
  );

local queueingHandledRequests =
  basic.multiTimeseries(
    'Workhorse queueing - handled requests',
    queries=[
      {
        legendFormat: 'handled',
        query: |||
          sum(
            gitlab_workhorse_queueing_busy{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
      {
        legendFormat: 'limit',
        query: |||
          sum(
            gitlab_workhorse_queueing_limit{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
    ],
  );

local queueingQueuedRequests =
  basic.multiTimeseries(
    'Workhorse queueing - queued requests',
    queries=[
      {
        legendFormat: 'queued',
        query: |||
          sum(
            gitlab_workhorse_queueing_waiting{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
      {
        legendFormat: 'limit',
        query: |||
          sum(
            gitlab_workhorse_queueing_queue_limit{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
    ],
  );

local queueingTime =
  local queueingTimeQuery(percentile) =
    {
      legendFormat: '%dth percentile' % percentile,
      query: |||
        histogram_quantile(
          0.%d,
          sum by (le) (
            rate(
              gitlab_workhorse_queueing_waiting_time_bucket{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}[$__interval]
            )
          )
        )
      ||| % percentile,
    };
  basic.multiTimeseries(
    'Workhorse queueing time',
    format='s',
    queries=[
      (
        queueingTimeQuery(percentile)
      )
      for percentile in [50, 90, 95, 99]
    ],
  );

{
  longPollingRequestStateCounter:: longPollingRequestStateCounter,
  longPollingOpenRequests:: longPollingOpenRequests,
  queueingErrors:: queueingErrors,
  queueingHandledRequests:: queueingHandledRequests,
  queueingQueuedRequests:: queueingQueuedRequests,
  queueingTime:: queueingTime,
}
