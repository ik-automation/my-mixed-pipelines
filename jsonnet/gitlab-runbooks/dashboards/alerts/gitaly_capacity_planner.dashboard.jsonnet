local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local template = grafana.template;
local link = grafana.link;

basic.dashboard(
  'Gitaly Capacity Planner',
  tags=['alert-target', 'gcp'],
  graphTooltip='shared_crosshair',
)
.addTemplate(template.new(
  'shard',
  '$PROMETHEUS_DS',
  'label_values(node_filesystem_size_bytes{type="gitaly", device="/dev/sdb", env="$environment"}, shard)',
  current='default',
  refresh='load',
  sort=1,
))
.addTemplate(template.new(
  'stage',
  '$PROMETHEUS_DS',
  'label_values(node_filesystem_size_bytes{type="gitaly", device="/dev/sdb", env="$environment", shard="$shard"}, stage)',
  current='main',
  refresh='load',
  sort=1,
))
.addTemplate(template.custom(
  'target_capacity',
  '50,55,60,65,70,75,80,85,90,95',
  '70',
))
.addPanels(layout.grid([
  grafana.text.new(
    title='Help',
    mode='markdown',
    content=|||
      # Gitaly Capacity Planning Dashboard

      This dashboard helps estimate the number of additional Gitaly nodes that will be needed
      to be provisioned in order to meet a specific capacity target. This capacity is measured as
      the total used capacity across all Gitaly nodes.

      **Ensure that you select the appropriate Gitaly environment, shard and stage using the template
      variable selector pulldowns above**.

      Then, select the appropriate target capacity using the `target_capacity` selector.
      This is a percentage value.

      This is closely related to the `gitaly_total_disk_space` metric, which monitors this capacity
      resource.
    |||
  ),
], cols=1, rowHeight=6))
.addPanels(layout.grid([
  basic.statPanel(
    title='Additional Gitaly Servers Required',
    panelTitle='Additional Gitaly Servers Required',
    color='light-red',
    legendFormat='Shard {{ shard }}',
    unit='new nodes',
    query=|||
      clamp_min(
        ceil(
          (
            (sum  by (environment, tier, type, stage, shard) (
              node_filesystem_size_bytes{type="gitaly", device="/dev/sdb", env="$environment", shard="$shard", stage="$stage"}
              -
              node_filesystem_free_bytes{type="gitaly", device="/dev/sdb", env="$environment", shard="$shard", stage="$stage"}
            )
            /
            avg by (environment, tier, type, stage, shard) (
              node_filesystem_size_bytes{type="gitaly", device="/dev/sdb", env="$environment", shard="$shard", stage="$stage"}
            )
          )
          /
          ($target_capacity / 100)
          )
          -
          count by (environment, tier, type, stage, shard) (
            node_filesystem_size_bytes{type="gitaly", device="/dev/sdb", env="$environment", shard="$shard", stage="$stage"}
          )
        ), 0
      )
    |||,
  ),
], cols=1, rowHeight=15))
.trailer()
