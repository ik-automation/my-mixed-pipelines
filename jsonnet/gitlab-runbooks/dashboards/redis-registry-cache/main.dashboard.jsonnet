local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local redisCommon = import 'gitlab-dashboards/redis_common_graphs.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';

serviceDashboard.overview('redis-registry-cache')
.addPanels(redisCommon.clientPanels(serviceType='redis-registry-cache', startRow=1001))
.addPanel(
  row.new(title='Workload'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(redisCommon.workload(serviceType='redis-registry-cache', startRow=2001))
.addPanel(
  row.new(title='Redis Data'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(redisCommon.data(serviceType='redis-registry-cache', startRow=3001))
.addPanel(
  row.new(title='Replication'),
  gridPos={
    x: 0,
    y: 4000,
    w: 24,
    h: 1,
  }
)
.addPanels(redisCommon.replication(serviceType='redis-registry-cache', startRow=4001))
.addPanel(
  row.new(title='Sentinel Processes', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'sentinel',
      {
        environment: '$environment',
        groupname: { re: 'redis-sentinel.*' },
        type: 'redis-registry-cache',
        stage: '$stage',
      },
      startRow=1
    )
  ),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  },
)
.overviewTrailer()
