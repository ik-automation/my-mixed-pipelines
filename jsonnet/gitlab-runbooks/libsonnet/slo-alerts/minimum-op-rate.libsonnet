local durationParser = import 'utils/duration-parser.libsonnet';

// For minimumSamplesForMonitoring, calculates what the minimum sample rate per second,
// over the longWindow needs to be. If null, returns null
{
  calculateFromSamplesForDuration(
    duration,
    sampleCount,
  ):
    if sampleCount == null then
      null
    else
      sampleCount / durationParser.toSeconds(duration),
}
