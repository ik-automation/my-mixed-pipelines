local multiburnFactors = import 'mwmbr/multiburn_factors.libsonnet';

{
  intervalByBurnType: {
    slow: '2m',
    fast: '1m',
  },

  intervalForDuration(duration)::
    self.intervalByBurnType[multiburnFactors.burnTypeForWindow(duration)],
}
