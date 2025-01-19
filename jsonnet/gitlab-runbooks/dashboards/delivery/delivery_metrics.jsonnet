local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prometheus = grafana.prometheus;
local graphPanel = grafana.graphPanel;

local explainer = |||
  This dashboard shows information about [delivery-metrics](https://gitlab.com/gitlab-org/release-tools/-/tree/master/metrics) deployment.

  This is for monitoring and debugging and should have no implications on release managers activities.
|||;

basic.dashboard(
  'delivery-metrics deployment',
  tags=[],
  editable=true,
  time_from='now-7d',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
)

.addPanels(
  layout.singleRow([
    grafana.text.new(
      title='delivery-metrics Explainer',
      mode='markdown',
      content=explainer,
    ),
  ], rowHeight=4, startRow=0)
)

// Deployed version
.addPanels(layout.singleRow([
  basic.table(
    'PODs',
    description='This table shows the pods running delivery-metrics with their revision and build date, except during a deployment, we expect to see only one pod',
    query='count(delivery_version_info) by (revision, build_date, pod)',
    transformations=[
      {
        // Exclude timestamp and value, which aren't meaningful here
        id: 'filterFieldsByName',
        options: {
          include: {
            names: ['revision', 'build_date', 'pod'],
          },
        },
      },
    ],
  ),
], rowHeight=4, startRow=100))

// memory
.addPanels(
  layout.grid(
    [
      // process memory
      graphPanel.new(
        'process memory',
        formatY1='bytes',
        formatY2='short',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'process_resident_memory_bytes{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}} - resident'
        )
      )
      .addTarget(
        prometheus.target(
          'process_virtual_memory_bytes{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}} - virtual'
        )
      ),

      graphPanel.new(
        'process memory deriv',
        formatY1='bytes',
        formatY2='short',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'rate(process_resident_memory_bytes{namespace="delivery",service="delivery-metrics"}[$__interval])',
          legendFormat='{{pod}} - resident'
        )
      )
      .addTarget(
        prometheus.target(
          'deriv(process_virtual_memory_bytes{namespace="delivery",service="delivery-metrics"}[$__interval])',
          legendFormat='{{pod}} - virtual'
        )
      ),


      // memstats
      graphPanel.new(
        'go memestat',
        formatY1='bytes',
        formatY2='Bps',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'go_memstats_alloc_bytes{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}} - bytes allocated'
        )
      )
      .addTarget(
        prometheus.target(
          'rate(go_memstats_alloc_bytes_total{namespace="delivery",service="delivery-metrics"}[30s])',
          legendFormat='{{pod}} - alloc rate'
        )
      )
      .addTarget(
        prometheus.target(
          'go_memstats_stack_inuse_bytes{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}} - stack inuse'
        )
      )
      .addTarget(
        prometheus.target(
          'go_memstats_heap_inuse_bytes{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}} - heap inuse'
        )
      ),

      graphPanel.new(
        'go memstats deriv',
        formatY1='bytes',
        formatY2='Bps',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'deriv(go_memstats_alloc_bytes{namespace="delivery",service="delivery-metrics"}[$__interval])',
          legendFormat='{{pod}} - bytes allocated'
        )
      )
      .addTarget(
        prometheus.target(
          'rate(go_memstats_alloc_bytes_total{namespace="delivery",service="delivery-metrics"}[$__interval])',
          legendFormat='{{pod}} - alloc rate'
        )
      )
      .addTarget(
        prometheus.target(
          'deriv(go_memstats_stack_inuse_bytes{namespace="delivery",service="delivery-metrics"}[$__interval])',
          legendFormat='{{pod}} - stack inuse'
        )
      )
      .addTarget(
        prometheus.target(
          'deriv(go_memstats_heap_inuse_bytes{namespace="delivery",service="delivery-metrics"}[$__interval])',
          legendFormat='{{pod}} - heap inuse'
        )
      ),
    ], startRow=200,
  ),
)

// open FDS
.addPanels(
  layout.grid(
    [
      graphPanel.new(
        'open fds',
        formatY1='short',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'process_open_fds{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}}'
        )
      ),

      graphPanel.new(
        'open fds deriv',
        formatY1='short',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'deriv(process_open_fds{namespace="delivery",service="delivery-metrics"}[$__interval])',
          legendFormat='{{pod}}'
        )
      ),


    ], startRow=300,
  ),
)


.addPanels(
  layout.grid(
    [
      // gorutines
      graphPanel.new(
        'gorountines',
        formatY1='s',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'go_goroutines{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}}'
        )
      ),

      // garbage collection
      graphPanel.new(
        'GC duration quintile',
        formatY1='short',

        legend_values=true,
        legend_max=true,
        legend_min=false,
        legend_avg=true,
        legend_current=true,
        legend_alignAsTable=true,
      )
      .addTarget(
        prometheus.target(
          'go_gc_duration_seconds{namespace="delivery",service="delivery-metrics"}',
          legendFormat='{{pod}}'
        )
      ),


    ], startRow=400,
  ),
)

.trailer()
