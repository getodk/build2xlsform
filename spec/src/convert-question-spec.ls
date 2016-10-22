# work around livescript syntax.
test = it

{ new-context, convert-question } = require('../lib/convert')

# this file is largely structured after the xlsform reference spec at:
# http://xlsform.org/ref-table/
#
# the grouping and ordering of tests reflect that table. the individual
# tests themselves in turn take after the structure of Build's UI. this
# ensures that tests are in a predictable, sensible order but also that
# every feature supported by Build is represented as expected here.
#
# some internal considerations, like pruning of noisy false fields, are
# tested at the very end, as are pass-on output like seen-fields.

# a basic input data you can inherit from to get the required stuff.
base =
  name: \test_question
  type: \inputNumber
  label:
    eng: 'A number, please.'

# if you don't care about the context, this is a convenience overload.
convert-simple = -> convert-question(it, new-context())

# type conversion does a number of things.
describe 'type' ->
  test 'text' ->
    result = (base with type: \inputText) |> convert-simple
    expect(result.type).toBe(\text)

