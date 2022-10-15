local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local strings = import 'strings.libsonnet';

test.suite({
  testRemoveBlankLines: {
    actual: strings.removeBlankLines(|||
      hello

      there

      you
    |||),
    expect: |||
      hello
      there
      you
    |||,
  },

  testChomp: {
    actual: strings.chomp('hello\n\n'),
    expect: 'hello',
  },
  testChompBlank: {
    actual: strings.chomp(''),
    expect: '',
  },
  testChompNewLines: {
    actual: strings.chomp('hello\nthere'),
    expect: 'hello\nthere',
  },

  testIndentBlank: {
    actual: strings.indent('', 2),
    expect: '',
  },
  testIndentSingleLine: {
    actual: strings.indent('hello', 2),
    expect: 'hello',
  },
  testIndentMultiLine: {
    actual: strings.indent('hello\nthere\nworld', 2),
    expect: 'hello\n  there\n  world',
  },
  testUnwrapTextEmpty: {
    actual: strings.unwrapText(''),
    expect: '',
  },
  testUnwrapSingleLine: {
    actual: strings.unwrapText('hello'),
    expect: 'hello',
  },
  testUnwrapText1: {
    actual: strings.unwrapText(|||
      This is some
      text

      This is a second paragraph.
    |||),
    expect: |||
      This is some text

      This is a second paragraph.
    |||,
  },
  testCapitalizeFirstLetterEmpty: {
    actual: strings.capitalizeFirstLetter(''),
    expect: '',
  },
  testCapitalizeFirstLetterHello: {
    actual: strings.capitalizeFirstLetter('hello'),
    expect: 'Hello',
  },
  testCapitalizeFirstLetterHelloAlreadyCaps: {
    actual: strings.capitalizeFirstLetter('Hello'),
    expect: 'Hello',
  },
  testCapitalizeFirstLetterSpace: {
    actual: strings.capitalizeFirstLetter(' '),
    expect: ' ',
  },
  testSplitOnCharsSingleChar: {
    actual: strings.splitOnChars('hello-there', '-'),
    expect: ['hello', 'there'],
  },
  testSplitOnCharsMultipleChar: {
    actual: strings.splitOnChars('hello-there+world', '-+'),
    expect: ['hello', 'there', 'world'],
  },
  testSplitOnCharsPrune: {
    actual: strings.splitOnChars('hello-+world', '-+'),
    expect: ['hello', 'world'],
  },
  testSplitOnEmptyString: {
    actual: strings.splitOnChars('', '-+'),
    expect: [],
  },
  testSplitOnSplittersOnly: {
    actual: strings.splitOnChars('+-++-', '-+'),
    expect: [],
  },
  testUrlEncoding: {
    actual: strings.urlEncode('type:git feature_category:groups'),
    expect: 'type%3Agit+feature_category%3Agroups',
  },
  testUrlEncodingWithInputReplacements: {
    actual: strings.urlEncode('type:git feature_category:groups', [[' ', '+']]),
    expect: 'type:git+feature_category:groups',
  },

  testMarkdownParagraphsTrivial: {
    actual: strings.markdownParagraphs([]),
    expect: '\n',
  },

  testMarkdownParagraphsSingle: {
    actual: strings.markdownParagraphs(['single']),
    expect: 'single\n',
  },

  testMarkdownParagraphsFilter: {
    actual: strings.markdownParagraphs(['p1', '', 'p2']),
    expect: 'p1\n\np2\n',
  },

  testMarkdownParagraphsFilterChomp: {
    actual: strings.markdownParagraphs(['\n\n\n\n', '', 'p2']),
    expect: 'p2\n',
  },

  testToCamelCaseTrivial: {
    actual: strings.toCamelCase(''),
    expect: '',
  },

  testToCamelCaseDashes: {
    actual: strings.toCamelCase('this-is-a-string'),
    expect: 'ThisIsAString',
  },

  testToCamelCaseUnderscores: {
    actual: strings.toCamelCase('this_is_a_string'),
    expect: 'ThisIsAString',
  },

  testToCamelCaseMixed: {
    actual: strings.toCamelCase('this-is_a-string'),
    expect: 'ThisIsAString',
  },

})
