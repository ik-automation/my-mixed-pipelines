local matching = import 'matching.libsonnet';
local test = import 'test.libsonnet';
test.suite({
  testMatcherFilter: {
    actual: matching.matcher('fieldName', 'test'),
    expect: {
      meta: {
        key: 'fieldName',
        params: 'test',
        type: 'phrase',
      },
      query: {
        match: {
          fieldName: {
            query: 'test',
            type: 'phrase',
          },
        },
      },
    },
  },
  testMatcherFilterIn: {
    actual: matching.matcher('fieldName', ['hello', 'world']),
    expect: {
      meta: {
        key: 'fieldName',
        params: ['hello', 'world'],
        type: 'phrases',
      },
      query: {
        bool: {
          should: [
            { match_phrase: { fieldName: 'hello' } },
            { match_phrase: { fieldName: 'world' } },
          ],
          minimum_should_match: 1,
        },
      },
    },
  },
  testMatchers: {
    local expectedScript = {
      bool: {
        minimum_should_match: 1,
        should: [
          { script: { script: { source: "doc['json.duration_s'].value > doc['json.target_duration_s'].value" } } },
          { script: { script: { source: 'script 2' } } },
        ],
      },
    },

    actual: matching.matchers({
      fieldName: ['hello', 'world'],
      rangeTest: { gte: 1, lte: 10 },
      equalMatch: 'match the exact thing',
      anyScript: ["doc['json.duration_s'].value > doc['json.target_duration_s'].value", 'script 2'],
    }),
    expect: [
      {
        meta: {
          key: 'query',
          type: 'custom',
          value: std.toString(expectedScript),
        },
        query: expectedScript,
      },
      {
        meta: {
          key: 'equalMatch',
          type: 'phrase',
          params: 'match the exact thing',
        },
        query: {
          match: {
            equalMatch: {
              query: 'match the exact thing',
              type: 'phrase',
            },
          },
        },
      },
      {
        meta: {
          key: 'fieldName',
          type: 'phrases',
          params: ['hello', 'world'],
        },
        query:
          {
            bool: {
              minimum_should_match: 1,
              should: [
                { match_phrase: { fieldName: 'hello' } },
                { match_phrase: { fieldName: 'world' } },
              ],
            },
          },
      },
      {
        meta: { key: 'rangeTest', params: { gte: 1, lte: 10 }, type: 'range' },
        query: { range: { rangeTest: { gte: 1, lte: 10 } } },
      },
    ],
  },
})
