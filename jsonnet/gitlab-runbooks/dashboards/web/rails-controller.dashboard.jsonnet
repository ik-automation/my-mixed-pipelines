local railsController = import 'gitlab-dashboards/rails_controller_common.libsonnet';

railsController.dashboard(type='web', defaultController='ProjectsController', defaultAction='show')
