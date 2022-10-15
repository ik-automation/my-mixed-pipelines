local union(sets) = std.foldl(function(memo, a) std.setUnion(std.set(a), memo), sets, []);

{
  dashboardUids:
    union([
      // Dashboards referenced from www-gitlab-com
      [
        '000000043',
        '000000045',
        '000000159',
        '1EBTz3Dmz',
        'RZmbBr7mk',
        'SOn6MeNmk',
        'SaIRBwuWk',
        'WO9bDCnmz',
        'bd2Kl9Imk',
        'l8ifheiik',
        'rKo7Hg1Wk',
        'sXVh89Imk',
        'sv_pUrImz',
      ],
      // Dashboards referenced from inside the runbooks repo
      [
        '000000144',
        '000000153',
        '000000159',
        '000000167',
        '000000204',
        '000000244',
        '7Zq1euZmz',
        '8EAXC-AWz',
        '9GOIu9Siz',
        '9T-wXWbik',
        'JyaDfEWWz',
        'PwlB97Jmk',
        'RZmbBr7mk',
        'USVj3qHmk',
        'VE4pXc1iz',
        'ZOOh_aNik',
        'bd2Kl9Imk',
        'fasrTtKik',
        'llfd4b2ik',
        'xSYVQ9Sik',
      ],
      // Quality owned dashboards
      [
        'Fyic5Wanz',
      ],
      // Dashboards that people have requested we save (for now!)
      [
        // ahegyi: loose foreign keys monitoring dashboard (WIP)
        'RKrvPFp7k',
        // mkaeppler: https://gitlab.com/gitlab-com/runbooks/-/merge_requests/2345#note_358065560
        'IGBZ5H_Zz',
        // hphilipps: osquery dashboard: https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10504
        'fjSLYzRWz',
        // cmiskell: "please keep fleet overview": https://gitlab.com/gitlab-com/runbooks/-/merge_requests/2345#note_358366125
        'mnbqU9Smz',
        // T4cC0re: "I would like to keep" https://gitlab.com/gitlab-com/runbooks/-/merge_requests/2345#note_358837191
        'FvOt_fNZk',
        // Brendan O'Leary/Andrew Newdigate: Vanity metrics dashboard
        'vanity-metrics',
      ],

      // bjk's dashboards
      // https://gitlab.com/gitlab-com/runbooks/-/merge_requests/2345#note_358186936
      [
        'J0QFZXomk',  // blackbox-ssh
        'Qe6veT_mk',  // fleet-utilization
        'pqlQq0xik',  // git-protocol-versions
        'x2SD_9Siz',  // go-processes
        '9l09q0qik',  // node-iostat
        'u0LwqvzWk',  // node-ntp
        '-UvftW1iz',  // ssh-performance
        '64YQGnbZz',  // thanos-store-oom
        '4QhoV1tZk',  // writes-per-gitaly-operation-copy
        'memcached',  // memcached
      ],
      // nnelson's dashboards
      // https://gitlab.com/gitlab-com/runbooks/-/merge_requests/2345#note_359096247
      [
        'W1v6W4JZk',
        'ApBISVEZk',
        'ZyUj4I2Zz',
        'Qv9RdwsZk',
        '7ef50NuWk',
        '-iBN4ZQZk',
        'yzukVGtZz',
        'O92e3k9Zk',
        'F2W0LV5Wk',
        '99GH9R8Wk',
      ],
      // SRE Personal Dashboards
      [
        'kQX9udS4z',
      ],
    ]),

  folderTitles: [
    'Geo Service',
    'CI Runners Service',
    'infrafin',
    'Gitaly Service',
    'GitLab-Rails Service',
    'End-User Performance',  // for Tim Zallmann's performance dashboards
    'Kubernetes',
    'Operations',
    'Cloudflare',
    'PostgreSQL',
    'Product',
    'Staging Reference',
  ],
}
