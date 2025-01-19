// TODO: export these numbers from GCP instead of hard-coding them
// TODO: export numbers for gstg and other non-prod environments

local subnetSizes = {
  // Source: https://console.cloud.google.com/networking/networks/list?project=gitlab-production
  'gitlab-gke-gprd': 510,
  'gke-us-east1-b-gprd': 254,
  'gke-us-east1-c-gprd': 254,
  'gke-us-east1-d-gprd': 254,
};

local subnetSizeRules = [
  {
    record: 'gitlab:gcp_subnet_max_ips',
    labels: {
      subnet: subnetName,
      env: 'gprd',
      environment: 'gprd',
    },
    expr: subnetSizes[subnetName],
  }
  for subnetName in std.objectFields(subnetSizes)
];

local clusterSubnetMapping = {
  // GKE cluster name : GCP subnet name
  // Source: https://console.cloud.google.com/kubernetes/list/overview?project=gitlab-production
  'gprd-gitlab-gke': 'gitlab-gke-gprd',
  'gprd-us-east1-b': 'gke-us-east1-b-gprd',
  'gprd-us-east1-c': 'gke-us-east1-c-gprd',
  'gprd-us-east1-d': 'gke-us-east1-d-gprd',
};

local clusterSubnetMappingRules = [
  {
    record: 'gitlab:cluster:subnet:mapping',
    labels: {
      subnet: clusterSubnetMapping[clusterName],
      cluster: clusterName,
      env: 'gprd',
      environment: 'gprd',
    },
    expr: 1,
  }
  for clusterName in std.objectFields(clusterSubnetMapping)
];

{
  'subnet-sizes.yml': std.manifestYamlDoc({
    groups: [
      {
        name: 'GCP Subnet size',
        interval: '1m',
        partial_response_strategy: 'warn',
        rules: subnetSizeRules,
      },
      {
        name: 'Subnet Cluster mapping',
        interval: '1m',
        partial_response_strategy: 'warn',
        rules: clusterSubnetMappingRules,
      },
    ],
  }),
}
