local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

local stageGroupDashboards = import './stage-group-dashboards.libsonnet';

local actionCableActiveConnections() =
  basic.timeseries(
    stableId='action_cable_active_connections',
    title='ActionCable Active Connections',
    decimals=2,
    yAxisLabel='Connections',
    description=|||
      Number of ActionCable connections active at the time of sampling.
    |||,
    query=|||
      sum(
        action_cable_active_connections{
          environment="$environment",
          stage="$stage",
        }
      )
    |||,
  );

local banzaiRequestCount() =
  basic.multiTimeseries(
    stableId='rendering_requests_count',
    title='Rendering Requests',
    decimals=2,
    yAxisLabel='Requests per Second',
    description=|||
      Number of Banzai rendering requests per second.

      `Cacheless` requests are those that are not cached in Redis (most requests).
      `Cached` requests attempt to use the Redis cache.
    |||,
    queries=[{
      query: |||
        sum(
          rate(
            gitlab_banzai_cacheless_render_real_duration_seconds_count{
              environment="$environment",
              stage='$stage',
            }[$__interval]
          )
        )
      |||,
      legendFormat: 'Cacheless',
    }, {
      query: |||
        sum(
          rate(
            gitlab_banzai_cached_render_real_duration_seconds_count{
              environment="$environment",
              stage='$stage',
            }[$__interval]
          )
        )
      |||,
      legendFormat: 'Cached',
    }],
  );

local banzaiAvgRenderingDuration() =
  basic.multiTimeseries(
    title='Rendering Time',
    decimals=2,
    format='s',
    yAxisLabel='',
    description=|||
      Duration of Banzai pipeline rendering
    |||,
    queries=[{
      query: |||
        sum(rate(gitlab_banzai_cacheless_render_real_duration_seconds_sum[1m]))
        /
        sum(rate(gitlab_banzai_cacheless_render_real_duration_seconds_count[1m]))
      |||,
      legendFormat: 'Average',
    }, {
      query: |||
        histogram_quantile(
          0.95,
          sum(
            rate(gitlab_banzai_cacheless_render_real_duration_seconds_bucket[1m])
          ) by (le)
        )
      |||,
      legendFormat: '95th Percentile',
    }, {
      query: |||
        histogram_quantile(
          0.99,
          sum(
            rate(gitlab_banzai_cacheless_render_real_duration_seconds_bucket[1m])
          ) by (le)
        )
      |||,
      legendFormat: '99th Percentile',
    }]
  );

stageGroupDashboards
.dashboard('project_management', components=stageGroupDashboards.supportedComponents)
.addPanels(
  layout.rowGrid(
    'Banzai Pipelines',
    [
      banzaiRequestCount(),
      banzaiAvgRenderingDuration(),
    ],
    startRow=1001
  ),
)
.addPanels(
  layout.rowGrid(
    'ActionCable Connections',
    [
      actionCableActiveConnections(),
    ],
    startRow=1101
  ),
)
.stageGroupDashboardTrailer()
