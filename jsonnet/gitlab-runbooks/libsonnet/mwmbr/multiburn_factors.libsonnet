local durationParser = import 'utils/duration-parser.libsonnet';

// For details of how these factors are calculated,
// read https://landing.google.com/sre/workbook/chapters/alerting-on-slos/
local hoursPerMonth = 24 * 30;

local windows = [
  { longWindow: '1h', shortWindow: '5m', forDuration: '2m', budgetThresholdForPeriod: 0.02 /* 2% */ },
  { longWindow: '6h', shortWindow: '30m', forDuration: '10m', budgetThresholdForPeriod: 0.05 /* 5% */ },
  { longWindow: '3d', shortWindow: '6h', forDuration: '1h', budgetThresholdForPeriod: 0.1 /* 10% */ },
];

/* MWMBR parameters, indexed by long window */
local parameters = std.foldl(function(memo, f) memo { [f.longWindow]: f { longWindowHours: durationParser.toSeconds(f.longWindow) / 3600 } },
                             windows,
                             {});

local burnTypeForDuration(window) =
  if durationParser.toSeconds(window) > durationParser.toSeconds('1h') then
    'slow'
  else
    'fast';

local burnTypeByWindow = std.foldl(
  function(memo, window)
    local burnType = burnTypeForDuration(window.longWindow);
    memo {
      [window.shortWindow]: burnType,
      [window.longWindow]: burnType,
    },
  windows,
  {}
);


local errorBudgetFactorFor(longWindow) =
  local budgetThresholdForPeriod = parameters[longWindow].budgetThresholdForPeriod;
  local longWindowHours = parameters[longWindow].longWindowHours;
  (budgetThresholdForPeriod * hoursPerMonth) / longWindowHours;

{
  windows: std.uniq(std.sort(std.flattenArrays(std.map(function(p) [p.longWindow, p.shortWindow], windows)))),
  burnTypeForWindow(window):
    if std.objectHas(burnTypeByWindow, window) then
      burnTypeByWindow[window]
    else
      burnTypeForDuration(window),

  /* Given a long window, returns the factor */
  errorBudgetFactorFor:: errorBudgetFactorFor,

  /* Lookup MWMBR params, given a long window */
  getParametersForLongWindow(longWindowDuration)::
    parameters[longWindowDuration],

  /**
   * Given an SLA and a window duration, returns the max error threshold.
   *
   * windowDuration should match one of the long window duration periods in the
   * parameters table.
   *
   * @param sla an SLA expressed as a fraction from 0 to 1. Eg 0.9995 = 99.95%
   * @param windowDuration a duration string - 1h, 6h, 1d
   * @return a threshold maximum error percentage for a 1 hour burn rate
   */
  errorRatioThreshold(sla, windowDuration)::
    errorBudgetFactorFor(windowDuration) * (1 - sla),

  /**
   * Given an SLA and a window duration, returns a min 1h apdex threshold.
   *
   * windowDuration should match one of the long window duration periods in the
   * parameters table.
   *
   * @param sla an SLA expressed as a fraction from 0 to 1. Eg 0.9995 = 99.95%
   * @param windowDuration a duration string - 1h, 6h, 1d
   * @return a threshold minimum apdex percentage for a 1 hour burn rate
   */
  apdexRatioThreshold(sla, windowDuration)::
    1 - errorBudgetFactorFor(windowDuration) * (1 - sla),

  alertForDurationForLongThreshold(longWindowDuration)::
    parameters[longWindowDuration].forDuration,
}
