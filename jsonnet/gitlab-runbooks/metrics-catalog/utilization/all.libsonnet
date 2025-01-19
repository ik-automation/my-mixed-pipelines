// Utilization resources are resources that we monitor and use in the
// capacity planning process, similar to saturation monitoring. Unlike
// saturation monitoring, utilization metrics to not have a defined maximum
// value which they cannot exceed.
[
  import 'cloudflare_data_transfer.libsonnet',
  import 'kube_node_requests.libsonnet',
  import 'pg_table_size.libsonnet',
  import 'pg_vacuum_time_per_day.libsonnet',
  import 'pg_dead_tup_rate.libsonnet',
  import 'pg_wraparound_time.libsonnet',
]
