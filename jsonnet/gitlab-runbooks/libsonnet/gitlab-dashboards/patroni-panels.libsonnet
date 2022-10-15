local pgbouncerCommonGraphs = import './pgbouncer_common_graphs.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local row = grafana.row;
local processExporter = import './process_exporter.libsonnet';
local serviceDashboard = import './service_dashboard.libsonnet';

local patroni(
  type='patroni',
  user='gitlab'
      ) =
  serviceDashboard.overview(type)
  .addPanel(
    row.new(title='pgbouncer Workload', collapse=false),
    gridPos={
      x: 0,
      y: 1000,
      w: 24,
      h: 1,
    }
  )
  .addPanels(pgbouncerCommonGraphs.workloadStats(type, 1001))
  .addPanel(
    row.new(title='pgbouncer Connection Pooling', collapse=false),
    gridPos={
      x: 0,
      y: 2000,
      w: 24,
      h: 1,
    }
  )
  .addPanels(pgbouncerCommonGraphs.connectionPoolingPanels(type, user, 2001))
  .addPanel(
    row.new(title='pgbouncer Network', collapse=false),
    gridPos={
      x: 0,
      y: 3000,
      w: 24,
      h: 1,
    }
  )
  .addPanels(pgbouncerCommonGraphs.networkStats(type, 3001))
  .addPanel(
    row.new(title='postgres process stats', collapse=true)
    .addPanels(
      processExporter.namedGroup(
        'postgres',
        {
          environment: '$environment',
          groupname: 'postgres',
          type: type,
          stage: 'main',
        },
      )
    )
    ,
    gridPos={
      x: 0,
      y: 4000,
      w: 24,
      h: 1,
    }
  )
  .addPanel(
    row.new(title='wal-g process stats', collapse=true)
    .addPanels(
      processExporter.namedGroup(
        'wal-g',
        {
          environment: '$environment',
          groupname: 'wal-g',
          type: type,
          stage: 'main',
        },
      )
    )
    ,
    gridPos={
      x: 0,
      y: 4010,
      w: 24,
      h: 1,
    }
  )

  .addPanel(
    row.new(title='patroni process stats', collapse=true)
    .addPanels(
      processExporter.namedGroup(
        type,
        {
          environment: '$environment',
          groupname: type,
          type: type,
          stage: 'main',
        },
      )
    )
    ,
    gridPos={
      x: 0,
      y: 4020,
      w: 24,
      h: 1,
    }
  )
  .overviewTrailer();

{
  patroni:: patroni,
}
