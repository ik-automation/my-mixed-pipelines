local layout = import './layout.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testRowsEmpty: {
    actual: layout.rows([]),
    expect: [],
  },
  testRowsSinglePanel: {
    actual: layout.rows([{ test: 1 }]),
    expect: [{ test: 1, gridPos: { h: 10, w: 24, x: 0, y: 0 } }],
  },
  testRowsSingleRow: {
    actual: layout.rows([[{ test: 1 }]]),
    expect: [{ test: 1, gridPos: { h: 10, w: 24, x: 0, y: 0 } }],
  },
  testRowsDoubleRows: {
    actual: layout.rows([[{ test: 1 }], [{ test: 2 }]]),
    expect: [
      { test: 1, gridPos: { h: 10, w: 24, x: 0, y: 0 } },
      { test: 2, gridPos: { h: 10, w: 24, x: 0, y: 10 } },
    ],
  },
  testRowsMixed: {
    actual: layout.rows([{ test: 1 }, [{ test: 2 }]]),
    expect: [
      { test: 1, gridPos: { h: 10, w: 24, x: 0, y: 0 } },
      { test: 2, gridPos: { h: 10, w: 24, x: 0, y: 10 } },
    ],
  },

})
