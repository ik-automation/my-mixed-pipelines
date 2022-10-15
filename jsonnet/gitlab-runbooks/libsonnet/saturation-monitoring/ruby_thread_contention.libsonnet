local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  ruby_thread_contention: resourceSaturationPoint({
    title: 'Ruby Thread Contention',
    severity: 's3',
    horizontallyScalable: true,  // Add more replicas for achieve greater scalability
    appliesTo: ['web', 'sidekiq', 'api', 'git', 'websockets'],
    description: |||
      Ruby (technically Ruby MRI), like some other scripting languages, uses a Global VM lock (GVL) also known as a
      Global Interpreter Lock (GIL) to ensure that multiple threads can execute safely. Ruby code is only allowed to
      execute in one thread in a process at a time. When calling out to c extensions, the thread can cede the lock to
      other thread while it continues to execute.

      This means that when CPU-bound workloads run in a multithreaded environment such as Puma or Sidekiq, contention
      with other Ruby worker threads running in the same process can occur, effectively slowing thoses threads down as
      they await GVL entry.

      Often the best fix for this situation is to add more workers by scaling up the fleet.
    |||,
    grafana_dashboard_uid: 'sat_ruby_thread_contention',
    resourceLabels: ['fqdn', 'pod'],  // We need both because `instance` is still an unreadable IP :|
    burnRatePeriod: '10m',
    quantileAggregation: 0.99,
    query: |||
      rate(ruby_process_cpu_seconds_total{%(selector)s}[%(rangeInterval)s])
    |||,
    slos: {
      soft: 0.75,
      hard: 0.85,
    },
  }),
}
