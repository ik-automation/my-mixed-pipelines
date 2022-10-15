local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local text = grafana.text;
local basic = import 'grafana/basic.libsonnet';
local dashboardHelpers = import 'stage-groups/verify-runner/dashboard_helpers.libsonnet';

local algorithmVisualisation =
  basic.multiTimeseries(
    title='Autoscaling algorithm',
    format='short',
    intervalFactor=5,
    legend_rightSide=true,
    queries=[
      {
        legendFormat: 'Number of running jobs',
        query: 'sum(gitlab_runner_jobs{environment=~"$environment", stage=~"$stage", instance=~"${runner_manager:pipe}"})',
      },
      {
        legendFormat: 'Number of {{state}} machines',
        query: 'sum by (state) (gitlab_runner_autoscaling_machine_states{environment=~"$environment", stage=~"$stage", instance=~"${runner_manager:pipe}", state=~"idle|used|creating|removing", executor="docker+machine"})',
      },
      {
        legendFormat: 'Number of existing machines',
        query: 'sum(gitlab_runner_autoscaling_machine_states{environment=~"$environment", stage=~"$stage", instance=~"${runner_manager:pipe}", state=~"idle|used|creating|removing", executor="docker+machine"})',
      },
      {
        legendFormat: 'Limit utilization',
        query: 'sum(gitlab_runner_jobs{environment=~"$environment", stage=~"$stage", instance=~"${runner_manager:pipe}"}) / sum(gitlab_runner_limit{instance=~"${runner_manager:pipe}"}) ',
      },
    ],
  )
  .resetYaxes()
  .addYaxis(
    format='short',
    show=true,
  )
  .addYaxis(
    format='percentunit',
    show=true,
  ) + {
    seriesOverrides+: [
      {
        alias: 'Number of running jobs',
        color: '#ffffff',
        lineWidth: 5,
        zindex: -3,
      },
      {
        alias: 'Number of existing machines',
        color: '#1F60C4',
        lineWidth: 3,
      },
      {
        alias: 'Number of creating machines',
        pointradius: 1,
        points: true,
      },
      {
        alias: 'Number of removing machines',
        pointradius: 1,
        points: true,
      },
      {
        alias: 'Number of used machines',
        lineWidth: 3,
      },
      {
        alias: 'Number of idle machines',
        lineWidth: 3,
      },
      {
        alias: 'Limit utilization',
        color: 'rgba(200, 242, 194, 0.85)',
        fill: 1,
        yaxis: 2,
        zindex: -2,
      },
    ],
  };

dashboardHelpers.dashboard(
  'Autoscaling algorithm',
  time_from='now-6h/m',
)
.addGrid(
  startRow=1000,
  rowHeight=3,
  panels=[
    text.new(
      title='',
      content=|||

        This dashboard is a visualization for the algorithm described at https://docs.gitlab.com/runner/configuration/autoscale.html.

        Look on it as for a replacement [for this graph](https://docs.gitlab.com/runner/configuration/img/autoscale-example.png) from the documentation page.
      |||,
    ),
  ],
)
.addGrid(
  startRow=2000,
  rowHeight=15,
  panels=[
    algorithmVisualisation,
  ],
)
