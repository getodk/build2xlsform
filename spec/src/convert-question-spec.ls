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

    result = { type: \inputDate, kind: 'Full Date' } |> convert-simple
    expect(result.type).toBe(\date)

  test \datetime ->
    result = { type: \inputDate, kind: 'Full Date and Time' } |> convert-simple
    expect(result.type).toBe(\dateTime)

  test \time ->
    result = { type: \inputTime } |> convert-simple
    expect(result.type).toBe(\time)

  test \geopoint ->
    result = { type: \inputLocation } |> convert-simple
    expect(result.type).toBe(\geopoint)

    result = { type: \inputLocation, kind: \Point } |> convert-simple
    expect(result.type).toBe(\geopoint)

  test \geotrace ->
    result = { type: \inputLocation, kind: \Path } |> convert-simple
    expect(result.type).toBe(\geotrace)

  test \geoshape ->
    result = { type: \inputLocation, kind: \Shape } |> convert-simple
    expect(result.type).toBe(\geoshape)

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

    today = { type: \metadata, kind: 'Today' } |> convert-simple
    expect(today.type).toBe(\today)

    username = { type: \metadata, kind: 'Username' } |> convert-simple
    expect(username.type).toBe(\username)

    subscriberid = { type: \metadata, kind: 'Subscriber ID' } |> convert-simple
    expect(subscriberid.type).toBe(\subscriberid)

    simserial = { type: \metadata, kind: 'SIM Serial' } |> convert-simple
    expect(simserial.type).toBe(\simserial)

    phonenumber = { type: \metadata, kind: 'Phone Number' } |> convert-simple
    expect(phonenumber.type).toBe(\phonenumber)

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

  test 'empty pruning' ->
    result = { type: \inputNumber, hint: {} } |> convert-simple
    expect(result.hint).toEqual(undefined)

describe \constraint ->
  test 'custom constraint passthrough' ->
    result = { type: \inputNumber, constraint: '. > 3' } |> convert-simple
    expect(result.constraint).toBe('(. > 3)')

  # n.b. there is a bug in build that exposes ui options for inclusivity that should not be there.
  test 'build text length constraint generation' ->
    result = { type: \inputText, length: { min: 42, max: 345 } } |> convert-simple
    expect(result.constraint).toBe('(regex(., "^.{42,345}$"))')

  test 'build text length false pruning' ->
    result = { type: \inputText, length: false } |> convert-simple
    expect(result.constraint).toBe(undefined)

  test 'build number/date range constraint generation (incl/excl combo)' ->
    result = { type: \inputNumber, range: { min: 3, minInclusive: true, max: 9 } } |> convert-simple
    expect(result.constraint).toBe('(. >= 3) and (. < 9)')

  test 'build number/date range constraint generation (excl/incl combo)' ->
    result = { type: \inputNumber, range: { min: 3, max: 9, maxInclusive: true } } |> convert-simple
    expect(result.constraint).toBe('(. > 3) and (. <= 9)')

  test 'build number/date range false pruning' ->
    result = { type: \inputText, range: false } |> convert-simple
    expect(result.constraint).toBe(undefined)

  test 'build select multiple response count constraint generation' ->
    result = { type: \inputSelectMany, count: { min: 3, max: 9, maxInclusive: true } } |> convert-simple
    expect(result.constraint).toBe('(count-selected(.) > 3) and (count-selected(.) <= 9)')

  test 'build select multiple response count false pruning' ->
    result = { type: \inputSelectMany, count: false } |> convert-simple
    expect(result.constraint).toBe(undefined)

  test 'custom constraint merging with build generation' ->
    result = { type: \inputNumber, constraint: '. != 5' range: { min: 3, max: 9 } } |> convert-simple
    expect(result.constraint).toBe('(. != 5) and (. > 3) and (. < 9)')

describe 'constraint message' ->
  test 'multilingual passthrough' ->
    result = { type: \inputNumber, invalidText: { en: \fun, sv: \roligt } } |> convert-simple
    expect(result.invalidText).toBe(undefined)
    expect(result.constraint_message).toEqual({ en: \fun, sv: \roligt })

  test 'empty pruning' ->
    result = { type: \inputNumber, invalidText: {} } |> convert-simple
    expect(result.invalidText).toBe(undefined)
    expect(result.constraint_message).toBe(undefined)

describe 'required' -> # in which we briefly become a bit existential.
  test 'true becomes yes' ->
    result = { type: \inputText, required: true } |> convert-simple
    expect(result.required).toBe(\yes)

  test 'false becomes nothing' ->
    falsy = { type: \inputText, required: false } |> convert-simple
    expect(falsy.required).toBe(undefined)

# required_message::lang is in the xlsform spec but is not in the build featureset.

describe 'default' ->
  test 'value is passed through' ->
    result = { type: \inputText, defaultValue: 'test default' } |> convert-simple
    expect(result.default).toBe('test default')

  test 'initial field is erased' ->
    result = { type: \inputText, defaultValue: 'test default' } |> convert-simple
    expect(result.defaultValue).toBe(undefined)

describe 'relevant' ->
  test 'value is passed through' ->
    result = { type: \inputText, relevance: 'some_var > 1' } |> convert-simple
    expect(result.relevant).toBe('some_var > 1')

  test 'initial field is erased' ->
    result = { type: \inputText, relevance: 'some_var > 1' } |> convert-simple
    expect(result.relevance).toBe(undefined)

describe 'read_only' ->
  test 'true becomes yes' ->
    result = { type: \inputText, readOnly: true } |> convert-simple
    expect(result.readOnly).toBe(undefined)
    expect(result.read_only).toBe(\yes)

  test 'false becomes nothing' ->
    falsy = { type: \inputText, readOnly: false } |> convert-simple
    expect(falsy.readOnly).toBe(undefined)
    expect(falsy.read_only).toBe(undefined)

describe 'calculation' ->
  test 'value is passed through' ->
    result = { type: \inputText, calculate: '2 + 2' } |> convert-simple
    expect(result.calculation).toBe('2 + 2')

  test 'initial field is erased' ->
    result = { type: \inputText, calculate: '2 + 2' } |> convert-simple
    expect(result.calculate).toBe(undefined)

# repeat_count is in the xlsform spec but is not in the build featureset.
# embedded media are in the xlsform spec but are not in the build featureset.

describe 'appearance' ->
  test 'group fieldlist flag becomes appearance prop if true' ->
    result = { type: \group, fieldList: true } |> convert-simple
    expect(result.fieldList).toBe(undefined)
    expect(result.appearance).toBe(\field-list)

  test 'group fieldlist flag vanishes if false' ->
    result = { type: \group, fieldList: false } |> convert-simple
    expect(result.fieldList).toBe(undefined)
    expect(result.appearance).toBe(undefined)

  test 'date precision: default' ->
    result = { type: \inputDate } |> convert-simple
    expect(result.type).toBe(\date)
    expect(result.appearance).toBe(undefined)

  test 'date precision: date and time' ->
    result = { type: \inputDate, kind: 'Full Date and Time' } |> convert-simple
    expect(result.type).toBe(\dateTime)
    expect(result.appearance).toBe(undefined)

  test 'date precision: year and month' ->
    result = { type: \inputDate, kind: 'Year and Month' } |> convert-simple
    expect(result.type).toBe(\date)
    expect(result.appearance).toBe(\month-year)
    expect(result.kind).toBe(undefined)

  test 'date precision: year' ->
    result = { type: \inputDate, kind: 'Year' } |> convert-simple
    expect(result.type).toBe(\date)
    expect(result.appearance).toBe(\year)
    expect(result.kind).toBe(undefined)

  test 'location appearances' ->
    result = { type: \inputLocation, appearance: 'Default (GPS)' } |> convert-simple
    expect(result.appearance).toBe(undefined)

    result = { type: \inputLocation, appearance: 'Show Map (GPS)' } |> convert-simple
    expect(result.appearance).toBe(\maps)

    result = { type: \inputLocation, appearance: 'Manual (No GPS)' } |> convert-simple
    expect(result.appearance).toBe(\placement-map)

  test 'select appearances' ->
    result = { type: \inputSelectOne, appearance: 'Default' } |> convert-simple
    expect(result.appearance).toBe(undefined)

    result = { type: \inputSelectOne, appearance: 'Minimal (spinner)' } |> convert-simple
    expect(result.appearance).toBe(\minimal)

    result = { type: \inputSelectOne, appearance: 'Table' } |> convert-simple
    expect(result.appearance).toBe(\label)

    result = { type: \inputSelectOne, appearance: 'Horizontal Layout' } |> convert-simple
    expect(result.appearance).toBe(\horizontal)

## from here on, we cover features not part of the xlsform spec.

# custom xpath bindings are in build but are *not* in xlsform:
describe 'destination' ->
  test 'generates a warning if used' ->
    context = new-context()
    result = convert-question({ type: \inputText, destination: '/custom/xpath' }, context)
    expect(result.destination).toBe(undefined)
    expect(context.warnings.length).toBe(1)

# groups become repeats:
describe 'group' ->
  test 'with loop becomes repeat' ->
    result = { type: \group, loop: true } |> convert-simple
    expect(result.loop).toBe(undefined)
    expect(result.type).toBe(\repeat)

  test 'without loop remains group' ->
    result = { type: \group, loop: false } |> convert-simple
    expect(result.loop).toBe(undefined)
    expect(result.type).toBe(\group)
    result = { type: \group } |> convert-simple
    expect(result.type).toBe(\group)

# options get copied to context:
describe 'options' ->
  test 'select one choices copied to context and removed' ->
    choices = [{ val: 3 }]
    context = new-context()
    result = convert-question({ type: \inputSelectOne, name: \test_select, options: choices }, context)
    expect(result.options).toBe(undefined)
    expect(context.choices.choices_test_select).toEqual(choices)

  test 'select many choices copied to context and removed' ->
    choices = [{ val: 3 }]
    context = new-context()
    result = convert-question({ type: \inputSelectMany, name: \test_select, options: choices }, context)
    expect(result.options).toBe(undefined)
    expect(context.choices.choices_test_select).toEqual(choices)

  test 'nested prefix is correctly applied' ->
    choices = [{ val: 3 }]
    context = new-context()
    result = convert-question({ type: \inputSelectOne, name: \test_select, options: choices }, context, [ \layer1, \layer2 ])
    expect(context.choices.choices_layer1_layer2_test_select).toEqual(choices)

  # TODO: no test for choice id collision.

# questions nested in groups are recursively processed:
describe 'group children' ->
  # use required flag mutation as a sign that processing happened.
  test 'one level down are processed' ->
    result = { type: \group, name: \layer1, children: [{ type: \inputText, required: true }] } |> convert-simple
    expect(result.children[0].required).toBe(\yes)

  test 'two levels down are processed' ->
    result = {
      type: \group, name: \layer1, children: [{
        type: \group, name: \layer2, children: [{
          type: \inputText, required: true
        }]
      }]
    } |> convert-simple
    expect(result.children[0].children[0].required).toBe(\yes)

  test 'correct prefix and context passed down' ->
    choices = [{ val: 3 }]
    context = new-context()
    result = convert-question({
      type: \group, name: \layer1, children: [{
        type: \group, name: \layer2, children: [{
          type: \inputSelectOne, name: \aselect, options: choices
        }]
      }]
    }, context)
    expect(context.choices.choices_layer1_layer2_aselect).toEqual(choices)

