local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local detailsMessage = |||
  These metrics are collected whenever a process that was spawned by gitaly exits.

  **Contrast to process metrics:**

  These metrics are more complete than the sampled process exporter metrics, in particular
  we account for all of the resources spent by short-lived processes -- which process sampling
  is prone to miss.

  **Pitfalls:**

  Because we only report on exit, long-running processes will only be shown here once they finish.
  Once they do, all of their spent resources will be accounted for in one go, which may look like
  a burst of activity.
|||;

{
  metricsForNode(selectorHash, includeDetails=true, aggregationLabels=['fqdn'], startRow=1)::
    local formatConfig = {
      selector: selectors.serializeHash(selectorHash),
      aggregationLabels: std.join(', ', aggregationLabels),
    };

    local legendFormat = std.join(' ', ['{{ ' + i + '}}' for i in aggregationLabels]);

    layout.grid([
      basic.timeseries(
        title='CPU Time',
        description='Seconds of CPU time consumed by gitaly child processes, per second. These are accounted once the process exits, so the reporting may occur later than the resource consumption.',
        query=|||
          sum by(%(aggregationLabels)s) (
            rate(
              gitaly_command_cpu_seconds_total{%(selector)s}[$__interval]
            )
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        intervalFactor=1,
        format='s',
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title='Context switches',
        description='Context switches incurred by child processes, per second. These are accounted once the process exits, so the reporting may occur later than the resource consumption.',
        query=|||
          sum by(%(aggregationLabels)s) (
            rate(
              gitaly_command_context_switches_total{%(selector)s}[$__interval]
            )
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title='Minor page faults',
        description='Minor page faults incurred by child processes, per second. These are accounted once the process exits, so the reporting may occur later than the resource consumption. The number of page faults serviced without any I/O activity; here I/O activity is avoided by "reclaiming" a page frame from the list of pages awaiting reallocation.',
        query=|||
          sum by(%(aggregationLabels)s) (
            rate(
              gitaly_command_minor_page_faults_total{%(selector)s}[$__interval]
            )
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title='Major page faults',
        description='Major page faults incurred by child processes, per second. These are accounted once the process exits, so the reporting may occur later than the resource consumption. The number of page faults serviced that required I/O activity.',
        query=|||
          sum by(%(aggregationLabels)s) (
            rate(
              gitaly_command_major_page_faults_total{%(selector)s}[$__interval]
            )
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
    ] + (
      if includeDetails then
        [grafana.text.new(
          title='Details',
          mode='markdown',
          content=detailsMessage,
        )]
      else
        []
    ), startRow=startRow),
}
