local serviceCatalogYaml = std.parseYaml(importstr './service-catalog.yml');
local teamsYaml = std.parseYaml(importstr './teams.yml');

serviceCatalogYaml
+
teamsYaml
