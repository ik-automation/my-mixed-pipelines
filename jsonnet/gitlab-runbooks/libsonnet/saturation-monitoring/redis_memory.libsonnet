local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

// How much of the entire node's memory is Redis using; relevant in the context of OOM kills
// and system constraints
local commonDefinition = {
  title: 'Redis Memory Utilization per Node',
  severity: 's2',
  horizontallyScalable: false,
  resourceLabels: ['fqdn'],
  query: |||
    max by (%(aggregationLabels)s) (
      label_replace(redis_memory_used_rss_bytes{%(selector)s}, "memtype", "rss","","")
      or
      label_replace(redis_memory_used_bytes{%(selector)s}, "memtype", "used","","")
    )
    /
    avg by (%(aggregationLabels)s) (
      node_memory_MemTotal_bytes{%(selector)s}
    )
  |||,
};

// How much of maxmemory (if configured) Redis is using; relevant
// for special cases like sessions which have both maxmemory and eviction, but
// don't want to actually reach that and start evicting under normal circumstances
local maxMemoryDefinition = {
  title: 'Redis Memory Utilization of Max Memory',
  severity: 's2',
  horizontallyScalable: false,
  resourceLabels: ['fqdn'],
  query: |||
    (
      max by (%(aggregationLabels)s) (
        redis_memory_used_bytes{%(selector)s}
      )
      /
      avg by (%(aggregationLabels)s) (
        redis_memory_max_bytes{%(selector)s}
      )
    ) and on (fqdn) redis_memory_max_bytes{%(selector)s} != 0
  |||,
};

local redisMemoryDefinition = commonDefinition {
  description: |||
    Redis memory utilization per node.

    As Redis memory saturates node memory, the likelyhood of OOM kills, possibly to the Redis process,
    become more likely.

    For caches, consider lowering the `maxmemory` setting in Redis. For non-caching Redis instances,
    this has been caused in the past by credential stuffing, leading to large numbers of web sessions.

    This threshold is kept deliberately low, since Redis RDB snapshots could consume a significant amount of memory,
    especially when the rate of change in Redis is high, leading to copy-on-write consuming more memory than when the
    rate-of-change is low.
  |||,
  grafana_dashboard_uid: 'sat_redis_memory',
  slos: {
    soft: 0.65,
    // Keep this low, since processes like the Redis RDB snapshot can put sort-term memory pressure
    // Ideally we don't want to go over 75%, so alerting at 70% gives us due warning before we hit
    //
    hard: 0.70,
  },
};

// All the redis except redis-tracechunks; includes sessions as well as
// the other sessions-specific metric below, as this measures something
// subtly different and distinctly valid
local excludedRedisInstances = ['redis-tracechunks'];

{
  redis_memory: resourceSaturationPoint(redisMemoryDefinition {
    appliesTo: std.filter(function(s) !std.member(excludedRedisInstances, s), metricsCatalog.findServicesWithTag(tag='redis')),
  }),


  redis_memory_cache: resourceSaturationPoint(maxMemoryDefinition {
    appliesTo: ['redis-cache'],
    description: |||
      Redis maxmemory utilization per node

      On the cache Redis we have maxmemory and an eviction policy as a
      safety-valve, but do not want or expect to reach that limit under
      normal circumstances; if we start evicting we will experience
      performance problems , so we want to be alerted some time before
      that happens.
    |||,
    grafana_dashboard_uid: 'sat_redis_memory_cache',
    slos: {
      soft: 0.70,
      hard: 0.75,
    },
  }),

  redis_memory_tracechunks: resourceSaturationPoint(commonDefinition {
    appliesTo: ['redis-tracechunks'],  // No need for tags, this is specifically targeted
    description: |||
      Redis memory utilization per node.

      As Redis memory saturates node memory, the likelyhood of OOM kills, possibly to the Redis process,
      become more likely.

      Trace chunks should be extremely transient (written to redis, then offloaded to objectstorage nearly immediately)
      so any uncontrolled growth in memory saturation implies a potentially significant problem.  Short term mitigation
      is usually to upsize the instances to have more memory while the underlying problem is identified, but low
      thresholds give us more time to investigate first

      This threshold is kept deliberately very low; because we use C2 instances we are generally overprovisioned
      for RAM, and because of the transient nature of the data here, it is advantageous to know early if there is any
      non-trivial storage occurring
    |||,
    grafana_dashboard_uid: 'sat_redis_memory_tracechunks',
    slos: {
      // Intentionally very low, maybe able to go lower.  See description above
      soft: 0.40,
      hard: 0.50,
    },
  }),

  redis_memory_sessions: resourceSaturationPoint(maxMemoryDefinition {
    appliesTo: ['redis-sessions'],  // No need for tags, this is specifically targeted
    description: |||
      Redis maxmemory utilization per node

      On the sessions Redis we have maxmemory and an eviction policy as a safety-valve, but
      do not want or expect to reach that limit under normal circumstances; if we start
      evicting we will start logging out users slightly early (although only the longest
      inactive sessions), so we want to be alerted some time before that happens.
    |||,
    grafana_dashboard_uid: 'sat_redis_memory_sessions',
    slos: {
      soft: 0.70,
      hard: 0.75,
    },
  }),

}
