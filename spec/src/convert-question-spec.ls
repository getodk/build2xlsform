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

# if you don't care about the context, this is a convenience overload.
convert-simple = -> convert-question(it, new-context())

# type conversion does a number of things.
describe \type ->
  test \text ->
    result = { type: \inputText } |> convert-simple
    expect(result.type).toBe(\text)

  test 'number: integer' ->
    explicit = { type: \inputNumeric, kind: \Integer } |> convert-simple
    expect(explicit.type).toBe(\integer)

    implicit = { type: \inputNumeric } |> convert-simple
    expect(implicit.type).toBe(\integer)

  test 'number: decimal' ->
    result = { type: \inputNumeric, kind: \Decimal } |> convert-simple
    expect(result.type).toBe(\decimal)

  test \date ->
    result = { type: \inputDate } |> convert-simple
    expect(result.type).toBe(\date)

  test \location ->
    result = { type: \inputLocation } |> convert-simple
    expect(result.type).toBe(\geopoint)

  test 'media: image' ->
    explicit = { type: \inputMedia, kind: \Image } |> convert-simple
    expect(explicit.type).toBe(\image)

    implicit = { type: \inputMedia } |> convert-simple
    expect(implicit.type).toBe(\image)

  test 'media: audio' ->
    result = { type: \inputMedia, kind: \Audio } |> convert-simple
    expect(result.type).toBe(\audio)

  test 'media: video' ->
    result = { type: \inputMedia, kind: \Video } |> convert-simple
    expect(result.type).toBe(\video)

  test \barcode ->
    result = { type: \inputBarcode } |> convert-simple
    expect(result.type).toBe(\barcode)

  test \metadata ->
    deviceid = { type: \metadata, kind: 'Device Id' } |> convert-simple
    expect(deviceid.type).toBe(\deviceid)

    start = { type: \metadata, kind: 'Start Time' } |> convert-simple
    expect(start.type).toBe(\start)

    end = { type: \metadata, kind: 'End Time' } |> convert-simple
    expect(end.type).toBe(\end)

  test 'select one' ->
    basic = { name: \test_select, type: \inputSelectOne, options: [] } |> convert-simple
    expect(basic.type).toBe('select_one choices_test_select')

    prefix = [ \nest_a, \nest_b ]
    nested = convert-question({ name: \my_select, type: \inputSelectOne, options: [] }, new-context(), prefix)
    expect(nested.type).toBe('select_one choices_nest_a_nest_b_my_select')

  test 'select multiple' ->
    basic = { name: \test_select, type: \inputSelectMany, options: [] } |> convert-simple
    expect(basic.type).toBe('select_multiple choices_test_select')

    prefix = [ \nest_a, \nest_b ]
    nested = convert-question({ name: \my_select, type: \inputSelectMany, options: [] }, new-context(), prefix)
    expect(nested.type).toBe('select_multiple choices_nest_a_nest_b_my_select')

  # group is tested here despite the final output being wonky, as we still want
  # to verify the intermediate form.
  test \group ->
    non-looping = { type: \group } |> convert-simple
    expect(non-looping.type).toBe(\group)

    looping = { type: \group, loop: true } |> convert-simple
    expect(looping.type).toBe(\repeat)
    expect(looping.loop).toBe(undefined)

describe \name ->
  test 'passthrough' ->
    result = { type: \inputNumber, name: \my_test_question } |> convert-simple
    expect(result.name).toBe(\my_test_question)

describe \label ->
  test 'multilingual passthrough' ->
    result = { type: \inputNumber, label: { en: \thanks, sv: \tack } } |> convert-simple
    expect(result.label).toEqual({ en: \thanks, sv: \tack })

describe \hint ->
  test 'multilingual passthrough' ->
    result = { type: \inputNumber, hint: { en: \thanks, sv: \tack } } |> convert-simple
    expect(result.hint).toEqual({ en: \thanks, sv: \tack })

