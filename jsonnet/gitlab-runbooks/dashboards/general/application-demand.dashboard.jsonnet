local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

basic.dashboard(
  'Application Demand Indicators',
  tags=['general'],
  time_from='now-6M',
  time_to='now',
  includeStandardEnvironmentAnnotations=false
)
.addPanels(
  layout.grid([
    grafana.text.new(
      title='Application Demand Indicators Help',
      mode='markdown',
      content=|||
        Application demand is used as a way to identify that there may have been an application level change that
        alters how the application makes requests of the underlying infrastructure.

        For more information, please view the [Indicators section on the Scalability Team
        Handbook Page](https://about.gitlab.com/handbook/engineering/infrastructure/team/scalability#application-demand).
      |||
    ),
  ], cols=1, rowHeight=4, startRow=100)
  +
  layout.grid([
    basic.timeseries(
      title='Sidekiq - average operations per week',
      query=|||
        (sum by (env) (avg_over_time(gitlab_service_ops:rate{type="sidekiq", stage="main", env="gprd", monitor="global"}[1w]))
         or
         sum by (env) (avg_over_time(gitlab_service_ops:rate{type="sidekiq", stage="main", env="gprd", monitor!="global"}[1w]))
         ) * 86400 * 7
      |||,
      legendFormat='{{env}}'
    ),
  ], cols=1, rowHeight=12, startRow=100)
  +
  layout.grid([
    basic.timeseries(
      title='Redis - average operations per week',
      query=|||
        (sum by (env, type) (avg_over_time(gitlab_service_ops:rate{type=~"redis|redis-cache|redis-sidekiq", stage="main", env="gprd", monitor="global"}[1w]))
        or
        sum by (env, type) (avg_over_time(gitlab_service_ops:rate{type=~"redis(-cache|-sidekiq)?", stage="main", env="gprd", monitor!="global"}[1w]))
        ) * 86400 * 7
      |||,
      legendFormat='{{env}} - {{type}}'
    ),
  ], cols=1, rowHeight=12, startRow=100)
)
