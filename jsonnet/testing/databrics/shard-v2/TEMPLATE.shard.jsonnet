local serviceDeployment = import "../TEMPLATE.service-deployment.jsonnet";

local newShard(customerName, release, env) = {
  local commonConf = {
    customerName: customerName,
    database: env.database,
  },

  local webapp = serviceDeployment + {
    serviceName:: customerName + "-webapp",
    dockerImage:: "webapp:" + release,
    serviceConf:: commonConf + {
      managerAddress: customerName + "-manager.prod.svc.cluster.local",
    },
  },

  local manager = serviceDeployment + {
    serviceName:: customerName + "-manager",
    dockerImage:: "manager:" + release,
    serviceConf:: commonConf,
  },

  apiVersion: "v1",
  kind: "List",
  items: std.flattenArrays([webapp.items, manager.items]),
};

// Export the function as a constructor for shards
{
  newShard:: newShard,
}
