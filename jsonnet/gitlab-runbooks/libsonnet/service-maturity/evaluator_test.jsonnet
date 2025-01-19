local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local evaluator = import 'service-maturity/evaluator.libsonnet';

local mockService = {
  type: 'mock',
  tier: 'test',
  skippedMaturityCriteria: {
    'Skipped Criteria 1': 'Reason A',
    'Skipped Criteria 2': 'Reason B',
  },
};
local levels = [
  {
    name: 'All passed',
    number: 1,
    criteria: [
      { name: 'Criteria 1', evidence: function(service) 'evidence 1' },
      { name: 'Criteria 2', evidence: function(service) ['evidence 2', 'evidence 3'] },
    ],
  },
  {
    name: 'All failed',
    number: 2,
    criteria: [
      { name: 'Criteria 1', evidence: function(service) false },
      { name: 'Criteria 2', evidence: function(service) false },
    ],
  },
  {
    name: 'All unimplemented',
    number: 3,
    criteria: [
      { name: 'Criteria 1', evidence: function(service) null },
      { name: 'Criteria 2', evidence: function(service) null },
    ],
  },
  {
    name: 'All skipped',
    number: 4,
    criteria: [
      { name: 'Skipped Criteria 1', evidence: function(service) null },
      { name: 'Skipped Criteria 2', evidence: function(service) null },
    ],
  },
  {
    name: '1 failed, 1 passed',
    number: 5,
    criteria: [
      { name: 'Criteria 1', evidence: function(service) false },
      { name: 'Criteria 2', evidence: function(service) 'evidence' },
    ],
  },
  {
    name: '2 unimplemented, 1 passed',
    number: 6,
    criteria: [
      { name: 'Criteria 1', evidence: function(service) 'evidence' },
      { name: 'Criteria 2', evidence: function(service) null },
      { name: 'Criteria 3', evidence: function(service) null },
    ],
  },
  {
    name: '2 skipped, 1 passed',
    number: 7,
    criteria: [
      { name: 'Skipped Criteria 1', evidence: function(service) false },
      { name: 'Criteria 1', evidence: function(service) 'evidence' },
      { name: 'Skipped Criteria 2', evidence: function(service) 'evidence' },
    ],
  },
  {
    name: '1 skipped, 1 unimplemented, 1 failed, 1 passed',
    number: 8,
    criteria: [
      { name: 'Criteria 1', evidence: function(service) false },
      { name: 'Criteria 2', evidence: function(service) null },
      { name: 'Skipped Criteria 1', evidence: function(service) 'evidence' },
      { name: 'Criteria 3', evidence: function(service) 'evidence' },
    ],
  },
];

test.suite({
  testEvaluation: {
    actual: evaluator.evaluate(mockService, levels),
    expect: [
      {
        name: 'All passed',
        passed: true,
        number: 1,
        criteria: [
          { name: 'Criteria 1', evidence: 'evidence 1', result: 'passed' },
          { name: 'Criteria 2', evidence: ['evidence 2', 'evidence 3'], result: 'passed' },
        ],
      },
      {
        name: 'All failed',
        passed: false,
        number: 2,
        criteria: [
          { name: 'Criteria 1', evidence: false, result: 'failed' },
          { name: 'Criteria 2', evidence: false, result: 'failed' },
        ],
      },
      {
        name: 'All unimplemented',
        passed: false,
        number: 3,
        criteria: [
          { name: 'Criteria 1', evidence: null, result: 'unimplemented' },
          { name: 'Criteria 2', evidence: null, result: 'unimplemented' },
        ],
      },
      {
        name: 'All skipped',
        passed: true,
        number: 4,
        criteria: [
          { name: 'Skipped Criteria 1', evidence: 'Reason A', result: 'skipped' },
          { name: 'Skipped Criteria 2', evidence: 'Reason B', result: 'skipped' },
        ],
      },
      {
        name: '1 failed, 1 passed',
        passed: false,
        number: 5,
        criteria: [
          { name: 'Criteria 1', evidence: false, result: 'failed' },
          { name: 'Criteria 2', evidence: 'evidence', result: 'passed' },
        ],
      },
      {
        name: '2 unimplemented, 1 passed',
        passed: true,
        number: 6,
        criteria: [
          { name: 'Criteria 1', evidence: 'evidence', result: 'passed' },
          { name: 'Criteria 2', evidence: null, result: 'unimplemented' },
          { name: 'Criteria 3', evidence: null, result: 'unimplemented' },
        ],
      },
      {
        name: '2 skipped, 1 passed',
        passed: true,
        number: 7,
        criteria: [
          { name: 'Skipped Criteria 1', evidence: 'Reason A', result: 'skipped' },
          { name: 'Criteria 1', evidence: 'evidence', result: 'passed' },
          { name: 'Skipped Criteria 2', evidence: 'Reason B', result: 'skipped' },
        ],
      },
      {
        name: '1 skipped, 1 unimplemented, 1 failed, 1 passed',
        passed: false,
        number: 8,
        criteria: [
          { name: 'Criteria 1', evidence: false, result: 'failed' },
          { name: 'Criteria 2', evidence: null, result: 'unimplemented' },
          { name: 'Skipped Criteria 1', evidence: 'Reason A', result: 'skipped' },
          { name: 'Criteria 3', evidence: 'evidence', result: 'passed' },
        ],
      },
    ],
  },
  testMaxLevel0: {
    actual: evaluator.maxLevel(
      mockService,
      [
        {
          name: 'Level 1',
          number: 1,
          criteria: [{ name: 'Criteria 1', evidence: function(service) false }],
        },
        {
          name: 'Level 2',
          number: 2,
          criteria: [{ name: 'Criteria 1', evidence: function(service) false }],
        },
      ]
    ),
    expect: { name: 'Level 0', number: 0 },
  },
  testMaxLevelMax: {
    actual: evaluator.maxLevel(
      mockService,
      [
        {
          name: 'Level 1',
          number: 1,
          criteria: [{ name: 'Criteria 1', evidence: function(service) '123' }],
        },
        {
          name: 'Level 2',
          number: 2,
          criteria: [{ name: 'Criteria 1', evidence: function(service) '456' }],
        },
        {
          name: 'Level 3',
          number: 3,
          criteria: [{ name: 'Criteria 1', evidence: function(service) '789' }],
        },
      ]
    ),
    expect: { name: 'Level 3', number: 3 },
  },
  testMaxLevelPassHigherLevelButFailedLowerOne: {
    actual: evaluator.maxLevel(
      mockService,
      [
        {
          name: 'Level 1',
          number: 1,
          criteria: [{ name: 'Criteria 1', evidence: function(service) '123' }],
        },
        {
          name: 'Level 2',
          number: 2,
          criteria: [{ name: 'Criteria 1', evidence: function(service) false }],
        },
        {
          name: 'Level 3',
          number: 3,
          criteria: [{ name: 'Criteria 1', evidence: function(service) '789' }],
        },
      ]
    ),
    expect: { name: 'Level 1', number: 1 },
  },
})
