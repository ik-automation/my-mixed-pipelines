// These are the standard labels in the GitLab label taxonomy.

{
  // No labels
  empty: 0,

  // The environment selector used for thanos (for gitlab.com, `env`)
  environmentThanos: 1 << 0,

  // The environment selector used for prometheus (for gitlab.com, `environment`)
  environment: 1 << 1,

  // The tier of the application (`db`, `stor, sv, fe, etc)
  tier: 1 << 2,

  // The service identifier (usually `type`)
  service: 1 << 3,

  // The stage, used for staggered versions (`main`, `cny` etc)
  stage: 1 << 4,

  // The shard, used for bulkheads for limiting saturation issues
  shard: 1 << 5,

  // The node name, eg `fqdn`
  node: 1 << 6,

  // A single SLI component of a service
  sliComponent: 1 << 7,
}
