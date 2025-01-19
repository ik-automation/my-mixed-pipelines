local basic = import 'grafana/basic.libsonnet';

local memoryUsage =
  basic.timeseries(
    title='Memory usage by instance',
    legendFormat='{{instance}}',
    format='percentunit',
    linewidth=2,
    fill=0,
    stack=false,
    query=|||
      instance:node_memory_utilization:ratio{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}
    |||,
  );

local cpuUsage =
  basic.timeseries(
    title='CPU usage by instance',
    legendFormat='{{instance}}',
    format='percentunit',
    linewidth=2,
    fill=0,
    stack=false,
    query=|||
      instance:node_cpu_utilization:ratio{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}
    |||,
  );

local fdsUsage =
  basic.timeseries(
    title='File Descriptiors usage by instance',
    legendFormat='{{instance}}',
    format='percentunit',
    linewidth=2,
    fill=0,
    stack=false,
    query=|||
      process_open_fds{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}",job="runners-manager"}
      /
      process_max_fds{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}",job="runners-manager"}
    |||,
  );

local diskAvailable =
  basic.timeseries(
    title='Disk available by instance and device',
    legendFormat='{{instance}} - {{device}}',
    format='percentunit',
    linewidth=2,
    fill=0,
    stack=false,
    query=|||
      instance:node_filesystem_avail:ratio{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}",fstype="ext4"}
    |||,
  );

local iopsUtilization =
  basic.multiTimeseries(
    title='IOPS',
    format='ops',
    linewidth=2,
    fill=0,
    stack=false,
    queries=[
      {
        legendFormat: '{{instance}} - writes',
        query: |||
          instance:node_disk_writes_completed:irate1m{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}
        |||,
      },
      {
        legendFormat: '{{instance}} - reads',
        query: |||
          instance:node_disk_reads_completed:irate1m{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}
        |||,
      },
    ],
  ) + {
    seriesOverrides+: [
      {
        alias: '/reads/',
        transform: 'negative-Y',
      },
    ],
  };

local networkUtilization =
  basic.multiTimeseries(
    title='Network Utilization',
    format='bps',
    linewidth=2,
    fill=0,
    stack=false,
    queries=[
      {
        legendFormat: '{{instance}} - sent',
        query: |||
          sum by (instance) (
            rate(node_network_transmit_bytes_total{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[$__interval])
          )
        |||,
      },
      {
        legendFormat: '{{instance}} - received',
        query: |||
          sum by (instance) (
            rate(node_network_receive_bytes_total{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[$__interval])
          )
        |||,
      },
    ],
  ) + {
    seriesOverrides+: [
      {
        alias: '/received/',
        transform: 'negative-Y',
      },
    ],
  };

{
  memoryUsage:: memoryUsage,
  cpuUsage:: cpuUsage,
  fdsUsage:: fdsUsage,
  diskAvailable:: diskAvailable,
  iopsUtilization:: iopsUtilization,
  networkUtilization:: networkUtilization,
}
