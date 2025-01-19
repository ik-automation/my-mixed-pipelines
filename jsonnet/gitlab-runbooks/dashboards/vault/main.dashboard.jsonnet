local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local row = grafana.row;

local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';

// See https://www.vaultproject.io/docs/internals/telemetry for more details about Vault metrics

serviceDashboard.overview('vault', startRow=1)
.addPanels(
  layout.grid([
    basic.statPanel(
      title='',
      panelTitle='Vault Leader Node',
      color='blue',
      query='vault_core_active{environment="$environment"}',
      legendFormat='{{ pod }}',
      colorMode='value',
      textMode='name',
    ),
    basic.statPanel(
      title='',
      panelTitle='Vault Raft Failure Tolerance',
      query='vault_autopilot_failure_tolerance{environment="$environment"}',
      legendFormat='',
      colorMode='value',
      textMode='value',
      unit='short',
      color=[
        { color: 'red', value: 0 },
        { color: 'orange', value: 1 },
        { color: 'green', value: 2 },
      ],
    ),
    basic.statPanel(
      title='',
      panelTitle='Vault Raft Autopilot Status',
      query='vault_autopilot_healthy{environment="$environment"}',
      legendFormat='',
      colorMode='value',
      textMode='value',
      mappings=[
        {
          id: 0,
          type: 1,
          value: '0',
          text: 'Not Healthy',
        },
        {
          id: 1,
          type: 1,
          value: '1',
          text: 'Healthy',
        },
      ],
      color=[
        { color: 'red', value: 0 },
        { color: 'green', value: 1 },
      ],
    ),
    basic.statPanel(
      title='',
      panelTitle='Vault Raft Autopilot Healthy Nodes',
      query='count(vault_autopilot_node_healthy{environment="$environment"} == 1)',
      legendFormat='',
      colorMode='value',
      textMode='value',
      unit='short',
      color=[
        { color: 'red', value: 0 },
        { color: 'orange', value: 4 },
        { color: 'green', value: 5 },
      ],
    ),
  ], cols=4, rowHeight=5, startRow=0),
)
.addPanel(
  row.new(title='Vault Core', collapse=true)
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='Barrier Operations Duration',
        description=|||
          Duration of time taken by GET/LIST/PUT/DELETE operations at the barrier.
        |||,
        query='vault_barrier_delete{environment="$environment"}',
        legendFormat='DELETE q{{ quantile }} ({{ pod }})',
        format='ms'
      )
      .addTarget(
        promQuery.target(
          'vault_barrier_get{environment="$environment"}',
          legendFormat='GET q{{ quantile }} ({{ pod }})',
        )
      )
      .addTarget(
        promQuery.target(
          'vault_barrier_list{environment="$environment"}',
          legendFormat='LIST q{{ quantile }} ({{ pod }})',
        )
      )
      .addTarget(
        promQuery.target(
          'vault_barrier_put{environment="$environment"}',
          legendFormat='PUT q{{ quantile }} ({{ pod }})',
        )
      ),
      basic.timeseries(
        title='Barrier Operations per Second',
        description=|||
          GET/LIST/PUT/DELETE operations per second at the barrier.
        |||,
        query='rate(vault_barrier_delete_count{environment="$environment"}[$__interval])',
        legendFormat='DELETE ({{ pod }})',
        format='ops'
      )
      .addTarget(
        promQuery.target(
          'rate(vault_barrier_get_count{environment="$environment"}[$__interval])',
          legendFormat='GET ({{ pod }})',
        )
      )
      .addTarget(
        promQuery.target(
          'rate(vault_barrier_list_count{environment="$environment"}[$__interval])',
          legendFormat='LIST ({{ pod }})',
        )
      )
      .addTarget(
        promQuery.target(
          'rate(vault_barrier_put_count{environment="$environment"}[$__interval])',
          legendFormat='PUT ({{ pod }})',
        )
      ),
    ], cols=2, rowHeight=10, startRow=0),
  )
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='Cache Hit/Miss Ratio',
        description=|||
          Cache hit/miss ratio.
        |||,
        query=|||
          sum(rate(vault_cache_hit{environment="$environment"}[$__interval]))
          /
          (
            sum(rate(vault_cache_hit{environment="$environment"}[$__interval]))
            +
            (sum(rate(vault_cache_miss{environment="$environment"}[$__interval])) or vector(0))
          )
        |||,
        legendFormat='hit',
        format='percentunit'
      ),
      basic.timeseries(
        title='Cache Write/Delete Operations per Second',
        description=|||
          Cache write/delete rate.
        |||,
        query='sum(rate(vault_cache_write{environment="$environment"}[$__interval]))',
        legendFormat='write',
        format='ops'
      )
      .addTarget(
        promQuery.target(
          'sum(rate(vault_cache_delete{environment="$environment"}[$__interval]))',
          legendFormat='delete',
        )
      ),
    ], cols=2, rowHeight=10, startRow=1),
  ),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanel(
  row.new(title='Vault Integrated Storage (Raft)', collapse=true)
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='Raft Transactions',
        description=|||
          Raft transaction rate.
        |||,
        query='rate(vault_raft_apply{environment="$environment"}[$__interval])',
        legendFormat='{{ pod }}',
        format='ops'
      ),
      basic.timeseries(
        title='Raft Commit Time',
        description=|||
          Time to commit a new entry to the Raft log on the leader.
        |||,
        query='vault_raft_commitTime{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
    ], cols=2, rowHeight=10, startRow=0),
  )
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='Raft Delete Time',
        description=|||
          Time to delete file from raft's underlying storage.
        |||,
        query='vault_raft_delete{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft Get Time',
        description=|||
          Time to retrieve file from raft's underlying storage.
        |||,
        query='vault_raft_get{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft List Time',
        description=|||
          Time to retrieve list of keys from raft's underlying storage.
        |||,
        query='vault_raft_list{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft Put Time',
        description=|||
          Time to persist key in raft's underlying storage.
        |||,
        query='vault_raft_put{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
    ], cols=4, rowHeight=10, startRow=1),
  )
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='Raft Replication Append Entries Rate',
        description=|||
          Number of logs replicated to a node, to bring it up to speed with the leader's logs.
        |||,
        query='rate(vault_raft_replication_appendEntries_logs{environment="$environment"}[$__interval])',
        legendFormat='{{ pod }}',
        format='short'
      ),
      basic.timeseries(
        title='Raft Replication Append Entries',
        description=|||
          Time taken by the append entries RPC, to replicate the log entries of a leader node onto its follower node(s).
        |||,
        query='vault_raft_replication_appendEntries_rpc{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft Replication Heartbeat',
        description=|||
          Time taken by the append entries RPC, to replicate the log entries of a leader node onto its follower node(s).
        |||,
        query='vault_raft_replication_heartbeat{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
    ], cols=3, rowHeight=10, startRow=3),
  )
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='Raft RPC Append Entries',
        description=|||
          Time taken to process an append entries RPC call from a node.
        |||,
        query='vault_raft_rpc_appendEntries{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft RPC Append Entries: Process Logs',
        description=|||
          Time taken to process the outstanding log entries of a node.
        |||,
        query='vault_raft_rpc_appendEntries_processLogs{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft RPC Append Entries: Store Logs',
        description=|||
          Time taken to add any outstanding logs for a node, since the last appendEntries was invoked.
        |||,
        query='vault_raft_rpc_appendEntries_storeLogs{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft RPC Process Heartbeat',
        description=|||
          Time taken to process a heartbeat request.
        |||,
        query='vault_raft_rpc_processHeartbeat{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
      basic.timeseries(
        title='Raft RPC Request Vote',
        description=|||
          Time taken to complete requestVote RPC call.
        |||,
        query='vault_raft_rpc_requestVote{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ),
    ], cols=5, rowHeight=10, startRow=4),
  ),
  gridPos={ x: 0, y: 210, w: 24, h: 1 },
)
.addPanel(
  row.new(title='Vault Integrated Storage (Raft) Leadership Changes', collapse=true)
  .addPanels(
    layout.grid([
      basic.timeseries(
        title='Raft Leader Last Contact',
        description=|||
          Time since the leader was last able to contact the follower nodes when checking its leader lease.
        |||,
        query='vault_raft_leader_lastContact{environment="$environment"}',
        legendFormat='{{ pod }} (p{{ quantile }})',
        format='ms'
      ) + {
        thresholds: [
          thresholds.warningLevel('gt', 200),
        ],
      },
      basic.timeseries(
        title='Raft State Changes',
        description=|||
          Candidate/follower/leader state changes.
        |||,
        query='increase(vault_raft_state_candidate{environment="$environment"}[$__interval])',
        legendFormat='{{ pod }}: candidate',
        format='short'
      )
      .addTarget(
        promQuery.target(
          'increase(vault_raft_state_follower{environment="$environment"}[$__interval])',
          legendFormat='{{ pod }}: follower',
        )
      )
      .addTarget(
        promQuery.target(
          'increase(vault_raft_state_leader{environment="$environment"}[$__interval])',
          legendFormat='{{ pod }}: leader',
        )
      ),
    ], cols=2, rowHeight=10, startRow=0),
  ),
  gridPos={ x: 0, y: 210, w: 24, h: 1 },
)
.overviewTrailer()
