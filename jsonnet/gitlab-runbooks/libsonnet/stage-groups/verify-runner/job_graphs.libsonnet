local panels = import './panels.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';

local aggregatorLegendFormat(aggregator) = '{{ %s }}' % aggregator;
local aggregatorsLegendFormat(aggregators) = '%s' % std.join(' - ', std.map(aggregatorLegendFormat, aggregators));

local aggregationTimeSeries(title, query, aggregators=[]) =
  local serializedAggregation = aggregations.serialize(aggregators);
  basic.timeseries(
    title=(title % serializedAggregation),
    legendFormat=aggregatorsLegendFormat(aggregators),
    format='short',
    linewidth=2,
    fill=1,
    stack=true,
    query=(query % serializedAggregation),
  );

local runningJobsGraph(aggregators=[]) =
  aggregationTimeSeries(
    'Jobs running on GitLab Inc. runners (by %s)',
    'sum by(%s) (gitlab_runner_jobs{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"})',
    aggregators,
  );

local runnerJobFailuresGraph(aggregators=[]) =
  aggregationTimeSeries(
    'Failures on GitLab Inc. runners (by %s)',
    |||
      sum by (%s)
      (
        increase(gitlab_runner_failed_jobs_total{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}",failure_reason=~"$runner_job_failure_reason"}[$__interval])
      )
    |||,
    aggregators,
  );

local startedJobsGraph(aggregators=[]) =
  aggregationTimeSeries(
    'Jobs started on runners (by %s)',
    |||
      sum by(%s) (
        increase(gitlab_runner_jobs_total{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[$__interval])
      )
    |||,
    aggregators,
  ) + {
    lines: false,
    bars: true,
    targets+: [{
      expr: |||
        avg (
          increase(gitlab_runner_jobs_total{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[$__interval])
        )
      |||,
      format: 'time_series',
      interval: '',
      intervalFactor: 10,
      legendFormat: 'avg',
    }],
    seriesOverrides+: [{
      alias: 'avg',
      bars: false,
      color: '#ff0000ff',
      fill: 0,
      lines: true,
      linewidth: 2,
      stack: false,
      zindex: 3,
    }],
  };

local startedJobsCounter =
  basic.statPanel(
    title=null,
    panelTitle='Started jobs',
    color='green',
    query='sum by(shard) (increase(gitlab_runner_jobs_total{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[1d]))',
    legendFormat='{{shard}}',
    unit='short',
    decimals=1,
    colorMode='value',
    instant=false,
    interval='1d',
    intervalFactor=1,
    reducerFunction='sum',
    justifyMode='center',
  );

local finishedJobsDurationHistogram = panels.heatmap(
  'Finished job durations histogram',
  |||
    sum by (le) (
      rate(gitlab_runner_job_duration_seconds_bucket{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[$__interval])
    )
  |||,
  intervalFactor=1,
  color_cardColor='blue',
);

local finishedJobsMinutesIncreaseGraph =
  basic.timeseries(
    title='Finished job minutes increase',
    legendFormat='{{shard}}',
    format='short',
    stack=true,
    interval='',
    intervalFactor=5,
    query=|||
      sum by(shard) (
        increase(gitlab_runner_job_duration_seconds_sum{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[$__interval])
      )/60
    |||,
  ) + {
    lines: false,
    bars: true,
    targets+: [{
      expr: |||
        avg (
          increase(gitlab_runner_job_duration_seconds_sum{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[$__interval])
        )/60
      |||,
      format: 'time_series',
      interval: '',
      intervalFactor: 10,
      legendFormat: 'avg',
    }],
    seriesOverrides+: [{
      alias: 'avg',
      bars: false,
      color: '#ff0000ff',
      fill: 0,
      lines: true,
      linewidth: 2,
      stack: false,
      zindex: 3,
    }],
  };

local finishedJobsMinutesIncreaseCounter =
  basic.statPanel(
    title=null,
    panelTitle='Finished job minutes increase',
    color='green',
    query=|||
      sum by(shard) (
        increase(gitlab_runner_job_duration_seconds_sum{environment=~"$environment",stage=~"$stage",instance=~"${runner_manager:pipe}"}[1d])
      )/60
    |||,
    legendFormat='{{shard}}',
    unit='short',
    decimals=1,
    colorMode='value',
    instant=false,
    interval='1d',
    intervalFactor=1,
    reducerFunction='sum',
    justifyMode='center',
  );

{
  running:: runningJobsGraph,
  failures:: runnerJobFailuresGraph,
  started:: startedJobsGraph,
  finishedJobsMinutesIncrease:: finishedJobsMinutesIncreaseGraph,

  startedCounter:: startedJobsCounter,
  finishedJobsMinutesIncreaseCounter:: finishedJobsMinutesIncreaseCounter,

  finishedJobsDurationHistogram:: finishedJobsDurationHistogram,
}
