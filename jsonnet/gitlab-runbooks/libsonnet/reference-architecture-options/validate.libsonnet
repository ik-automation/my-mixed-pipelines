local validator = import 'utils/validator.libsonnet';

// This provides a validator, plus defaults for
// `gitlab-metrics-options.libsonnet`. For details, please refer to the README.md file at
// https://gitlab.com/gitlab-com/runbooks/-/blob/master/reference-architectures/README.md.

local defaults = {
  // NOTE: when updating this option set, please ensure that the
  // documentation regarding options is updated at
  // reference-architectures/README.md#options
  praefect: {
    // The reference architecture makes Praefect/Gitaly-Cluster optional
    // Override this to disable Praefect monitoring
    enable: true,
  },
};

local referenceArchitectureOptionsValidator = validator.new({
  praefect: {
    enable: validator.boolean,
  },
});

function(overrides)
  local v = defaults + overrides;
  referenceArchitectureOptionsValidator.assertValid(v)
