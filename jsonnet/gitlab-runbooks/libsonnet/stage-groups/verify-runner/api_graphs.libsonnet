local basic = import 'grafana/basic.libsonnet';

local jobRequestsOnWorkhorse =
  basic.timeseries(
    '`jobs/request` requests',
    format='ops',
    legendFormat='requests',
    query=|||
      sum(
        job:gitlab_workhorse_http_request_duration_seconds_count:rate1m{environment=~"$environment",stage=~"$stage",route=~".*/api/v4/jobs/request.*"}
      )
    |||,
  );

local runnerRequests(endpoint, statuses='.*') =
  basic.timeseries(
    'Runner requests for %(endpoint)s [%(statuses)s]' % {
      endpoint: endpoint,
      statuses: statuses,
    },
    format='ops',
    legendFormat='{{status}}',
    stack=true,
    query=|||
      sum by(status) (
        increase(
          gitlab_runner_api_request_statuses_total{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}",endpoint="%(endpoint)s",status=~"%(statuses)s"}[$__interval]
        )
      )
    ||| % {
      endpoint: endpoint,
      statuses: statuses,
    },
  ) + {
    lines: false,
    bars: true,
  };

{
  jobRequestsOnWorkhorse:: jobRequestsOnWorkhorse,
  runnerRequests:: runnerRequests,
}
