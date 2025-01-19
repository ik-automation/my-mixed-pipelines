local panels = import 'gitlab-dashboards/pgbouncer-panels.libsonnet';

panels.pgbouncer('pgbouncer-ci').overviewTrailer()
