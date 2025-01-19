local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  namedGroup(title, selectorHash, aggregationLabels=['fqdn'], startRow=1)::
    local formatConfig = {
      selector: selectors.serializeHash(selectorHash),
      aggregationLabels: std.join(', ', aggregationLabels),
    };

    local legendFormat = std.join(' ', ['{{ ' + i + '}}' for i in aggregationLabels]);

    layout.grid([
      basic.timeseries(
        title=title + ': CPU Time',
        description='Seconds of CPU time for the named process group, per second. Note that this metric is sampled periodically, and thus will greatly under-sample short-lived processes.',
        query=|||
          sum by(%(aggregationLabels)s) (
            rate(
              namedprocess_namegroup_cpu_seconds_total{%(selector)s}[$__interval]
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
        title=title + ': Open File Descriptors',
        description='Maximum number of open file descriptors per host',
        query=|||
          max by(%(aggregationLabels)s) (
              namedprocess_namegroup_open_filedesc{%(selector)s}
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title=title + ': Number of Processes',
        description='Number of processes in the process group',
        query=|||
          sum by(%(aggregationLabels)s) (
            avg_over_time(namedprocess_namegroup_num_procs{%(selector)s}[$__interval])
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title=title + ': Number of Threads',
        description='Number of threads in the process group',
        query=|||
          sum by(%(aggregationLabels)s) (
            namedprocess_namegroup_num_threads{%(selector)s}
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
      basic.timeseries(
        title=title + ': RSS Memory Usage',
        description='Resident Memory usage for named process group',
        query=|||
          sum by(%(aggregationLabels)s) (
            namedprocess_namegroup_memory_bytes{memtype="resident", %(selector)s}
          )
        ||| % formatConfig,
        legendFormat=legendFormat,
        interval='1m',
        format='bytes',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
    ], startRow=startRow),
}
