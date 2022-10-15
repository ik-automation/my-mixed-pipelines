local durationParser = import 'utils/duration-parser.libsonnet';

local dynamicRange = '$__range';
local isDynamicRange(range) = range == dynamicRange;

{
  dynamicRange: dynamicRange,
  isDynamicRange: isDynamicRange,
  rangeInSeconds(range):
    if isDynamicRange(range) then
      '$__range_s'
    else
      durationParser.toSeconds(range),
  budgetSeconds(slaTarget, range):
    if isDynamicRange(range) then
      '(1 - %(slaTarget).4f) * $__range_s' % slaTarget
    else
      (1 - slaTarget) * durationParser.toSeconds(range),
  budgetMinutes(slaTarget, range):
    if isDynamicRange(range) then
      '(1 - %(slaTarget).4f) * $__range_s / 60.0' % slaTarget
    else
      (1 - slaTarget) * durationParser.toSeconds(range) / 60.0,
}
