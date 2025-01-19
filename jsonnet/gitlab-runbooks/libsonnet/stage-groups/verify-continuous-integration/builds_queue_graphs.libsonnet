local basic = import 'grafana/basic.libsonnet';

local bigQueryDuration(percentiles=[50, 90, 99]) =
  local histogramQuery(percentile) =
    {
      query: |||
        histogram_quantile(
          0.%d,
          sum by (le, runner_type) (
            rate(
              gitlab_ci_queue_retrieval_duration_seconds_bucket{
                environment="$environment",
                stage="$stage",
                runner_type=~"${runner_type:pipe}"
              }[$__interval]
            )
          )
        )
      ||| % percentile,
      legendFormat: '{{ runner_type }} - p%d' % percentile,
    };
  basic.multiTimeseries(
    stableId='builds-queue-big-query-duration',
    title='Duration of the builds queue retrieval using the big query SQL',
    format='s',
    queries=[
      (
        histogramQuery(percentile)
      )
      for percentile in percentiles
    ],
  );

{
  bigQueryDuration:: bigQueryDuration,
}
