local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview('postgres-archive')
.overviewTrailer()
