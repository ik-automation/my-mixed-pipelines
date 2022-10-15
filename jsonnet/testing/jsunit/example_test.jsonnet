// https://github.com/yugui/jsonnetunit
local test = import "lib/test.libsonnet";

test.suite({
    testIdentity: {actual: 1, expect: 1},
    testNeg:      {actual: "YAML", expectNot: "Markup Language"},
    testFact: {
        local fact(n) = if n == 0 then 1 else n * fact(n-1),

        actual: fact(10),
        expect: 3628800
    },
})
