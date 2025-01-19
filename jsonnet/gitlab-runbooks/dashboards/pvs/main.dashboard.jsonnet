local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

serviceDashboard.overview('pvs')
.addPanels(
  layout.grid([
    basic.timeseries(
      title='Rejected requests per hour (rolling)',
      query=|||
        sum by () (
          increase(stackdriver_cloud_run_revision_run_googleapis_com_request_count{
            configuration_name="pipeline-validation-service",
            env="$environment",
            environment="$environment",
            response_code="406"
          }[1h])
        )
      |||,
      legendFormat='Unacceptable Requests per Hour',
      format='ops',
      interval='5m',
      intervalFactor=1,
      yAxisLabel='Requests',
      legend_show=true,
      linewidth=2
    ),
    basic.percentageTimeseries(
      title='Rejected requests as a percentage of all requests',
      query=|||
        sum(
          rate(stackdriver_cloud_run_revision_run_googleapis_com_request_count{
            configuration_name="pipeline-validation-service",
            env="$environment",
            environment="$environment",
            response_code="406"
          }[1h])
        )
        /
        sum(
          rate(stackdriver_cloud_run_revision_run_googleapis_com_request_count{
            configuration_name="pipeline-validation-service",
            env="$environment",
            environment="$environment",
          }[1h])
        )
      |||,
      legendFormat='Unacceptable Requests %',
      interval='5m',
      intervalFactor=1,
      legend_show=true,
      linewidth=2
    ),
  ], cols=1, rowHeight=10, startRow=1001)
)
.overviewTrailer()
