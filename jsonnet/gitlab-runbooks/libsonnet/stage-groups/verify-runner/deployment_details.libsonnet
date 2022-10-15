local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local text = grafana.text;

local table(title, query, sortBy=[], transform_organize={}, transform_groupBy={}) = (
  basic.table(
    title=title,
    query=query,
    styles=null
  ) {
    options+: {
      sortBy: sortBy,
    },
    transformations: [
      {
        id: 'organize',
        options: transform_organize,
      },
      {
        id: 'groupBy',
        options: {
          fields: transform_groupBy,
        },
      },
    ],
  }
);

local versionsTable = table(
  title='GitLab Runner Versions',
  query='gitlab_runner_version_info{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}',
  sortBy=[{
    desc: true,
    displayName: 'version',
  }],
  transform_organize={
    excludeByName: {
      Time: true,
      Value: true,
      __name__: true,
      branch: true,
      built_at: true,
      env: true,
      environment: true,
      fqdn: true,
      job: true,
      monitor: true,
      name: true,
      provider: true,
      region: true,
      shard: true,
      stage: true,
      tier: true,
      type: true,
    },
    indexByName: {
      instance: 0,
      version: 1,
      revision: 2,
      os: 3,
      architecture: 4,
      go_version: 5,
    },
    renameByName: {
      architecture: 'arch',
      go_version: '',
      revision: '',
    },
  },
  transform_groupBy={
    instance: {
      aggregations: ['last'],
      operation: 'aggregate',
    },
  }
) + {
  fieldConfig+: {
    overrides+: [
      {
        matcher: { id: 'byName', options: 'instance' },
        properties: [{ id: 'custom.width', value: null }],
      },
      {
        matcher: { id: 'byName', options: 'version' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
      {
        matcher: { id: 'byName', options: 'revision' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
      {
        matcher: { id: 'byName', options: 'os' },
        properties: [{ id: 'custom.width', value: 80 }],
      },
      {
        matcher: { id: 'byName', options: 'arch' },
        properties: [{ id: 'custom.width', value: 80 }],
      },
      {
        matcher: { id: 'byName', options: 'go_version' },
        properties: [{ id: 'custom.width', value: 90 }],
      },
    ],
  },
};

local uptimeTable = table(
  'GitLab Runner Uptime',
  query='time() - process_start_time_seconds{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}",job="runners-manager"}',
  sortBy=[{
    asc: true,
    displayName: 'Uptime (last)',
  }],
  transform_organize={
    excludeByName: {
      Time: true,
      env: true,
      environment: true,
      fqdn: true,
      job: true,
      monitor: true,
      provider: true,
      region: true,
      shard: true,
      stage: true,
      tier: true,
      type: true,
    },
    indexByName: {
      instance: 0,
      Value: 1,
    },
    renameByName: {
      Value: 'Uptime',
    },
  },
  transform_groupBy={
    instance: {
      aggregations: [],
      operation: 'groupby',
    },
    Uptime: {
      aggregations: ['last'],
      operation: 'aggregate',
    },
  }
) + {
  fieldConfig+: {
    defaults+: {
      unit: 's',
    },
    overrides+: [
      {
        matcher: { id: 'byName', options: 'instance' },
        properties: [{ id: 'custom.width', value: null }],
      },
      {
        matcher: { id: 'byName', options: 'Uptime (last)' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
    ],
  },
};

local runnerManagersCounter =
  basic.statPanel(
    title=null,
    panelTitle='Runner managers count',
    color='green',
    query='count by(shard) (gitlab_runner_version_info{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"})',
    legendFormat='{{shard}}',
    unit='short',
    decimals=0,
    colorMode='value',
    instant=true,
    interval='1d',
    intervalFactor=1,
    reducerFunction='last',
    justifyMode='center',
  );

local notes = text.new(
  title='Notes',
  mode='markdown',
  content=|||
    ## Useful links

    - [Deployments Merge Requests](https://gitlab.com/gitlab-com/gl-infra/chef-repo/-/merge_requests?scope=all&utf8=%E2%9C%93&state=merged&label_name[]=group%3A%3Arunner&label_name[]=deploy).
  |||
);

{
  versions:: versionsTable,
  uptime:: uptimeTable,
  notes:: notes,
  runnerManagersCounter:: runnerManagersCounter,
}
