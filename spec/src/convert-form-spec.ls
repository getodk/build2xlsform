# work around livescript syntax.
test = it

{ convert-form, gen-settings } = require('../lib/convert')

# because convert-form depends on accrued context from repeatedly calling
# convert-question and thus calls convert-question itself, this set of tests
# serve as an effective end-to-end test of the entire conversion pipeline
# from build-json to xls-json.
#
# the first set of tests focus on accurate schema generation of both sheets.
#
# the next set test basic row generation in all three sheets.
#
# the final set tests more-complex generation regimes involving groups/repeats.

# util.
describe 'schema generation:' ->
  describe 'main schema' ->
    test 'basic fields based on a question' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \English, _counter: 0 }
        controls: [
          { type: \inputText, name: \my_field, constraint: '. != "xyz"' }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name, \constraint ])

    test 'basic fields based on multiple questions' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \English, _counter: 0 }
        controls: [
          { type: \inputText, name: \my_field, constraint: '. != "xyz"' },
          { type: \inputText, name: \your_field, required: true }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name, \required, \constraint ])

    test 'ignores pruned fields' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \English, _counter: 0 }
        controls: [
          { type: \inputText, name: \my_field, label: {}, readOnly: false },
          { type: \inputText, name: \your_field, required: false }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name ])

    test 'ignores nonsense fields' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \English, _counter: 0 }
        controls: [
          { type: \inputText, name: \my_field, nonsense: \test },
          { type: \inputText, name: \your_field, other_nonsense: 3 }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \name ])

    test 'generates appropriate language-keyed fields' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, 1: \sv, 2: \hi, _counter: 2 }
        controls: [
          { type: \inputText, label: { 0: \hello }, hint: { 0: \hi } },
          { type: \inputText, constraint_message: { 2: \challo } }
        ]
      )

      expect(result[0].data[0]).toEqual([ \type, \label::en, \label::sv, \label::hi, \hint::en, \hint::sv, \hint::hi, \constraint_message::en, \constraint_message::sv, \constraint_message::hi ])

  describe 'choice schema' ->
    test 'generation incl language-keyed fields' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, 1: \es, _counter: 1 }
        controls: [ ]
      )

      expect(result[1].data[0]).toEqual([ 'list name', \name, \label::en, \label::es ])

describe 'row generation:' ->
  describe 'main sheet' ->
    test 'basic values end up in the correct spot' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [
          { type: \inputText, name: \my_field, constraint: '. != "xyz"' }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \my_field, '(. != "xyz")' ])

    test 'absent values end up appropriately blank' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [
          { type: \inputText, name: \my_field },
          { type: \inputText, name: \other_field, required: true, readOnly: true }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \my_field, undefined, undefined ])

    test 'appropriate number of rows in result' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [
          { type: \inputText, name: \my_field },
          { type: \inputText, name: \other_field },
          { type: \inputText, name: \yet_another_field }
        ]
      )

      expect(result[0].data.length).toEqual(4)

    test 'language-keyed fields correctly populated' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \sv, 1: \en, _counter: 1 }
        controls: [
          { type: \inputText, label: { 1: \hello, 0: \hej }, hint: { 1: \thanks, 0: \tack } }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \hej, \hello, \tack, \thanks ])

    test 'partially missing language-keyed fields appropriately blank' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, 1: \sv, _counter: 1 }
        controls: [
          { type: \inputText, label: { 0: \hello }, hint: { 1: \tack } }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, \hello, undefined, undefined, \tack ])

    test 'entirely missing language-keyed fields appropriately blank' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \sv, 1: \en, _counter: 1 }
        controls: [
          { type: \inputText, label: { 1: \hello } },
          { type: \inputText, hint: { 0: \tack } }
        ]
      )

      expect(result[0].data[1]).toEqual([ \text, undefined, \hello, undefined, undefined ])

  describe 'choice sheet' ->
    test 'choice data correctly mapped' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [
          { type: \inputSelectOne, name: \testselect, options: [
            { text: { 0: 'option a' }, val: \alpha }
          ] }
        ]
      )

      expect(result[1].data[1]).toEqual([ \choices_testselect, \alpha, 'option a' ])

    test 'expected number of choices outputted' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [
          { type: \inputSelectOne, name: \testselect, options: [
            { text: { 0: 'option a' }, val: \alpha },
            { text: { 0: 'option b' }, val: \bravo },
            { text: { 0: 'option c' }, val: \charlie },
            { text: { 0: 'option d' }, val: \delta }
          ] },
          { type: \inputSelectMany, name: \testselecttwo, options: [
            { text: { 0: 'option e' }, val: \echo },
            { text: { 0: 'option f' }, val: \foxtrot },
            { text: { 0: 'option g' }, val: \golf },
            { text: { 0: 'option h' }, val: \hotel }
          ] }
        ]
      )

      expect(result[1].data).toEqual([
        [ 'list name', \name, \label::en ],
        [ \choices_testselect, \alpha, 'option a' ],
        [ \choices_testselect, \bravo, 'option b' ],
        [ \choices_testselect, \charlie, 'option c' ],
        [ \choices_testselect, \delta, 'option d' ],
        [ \choices_testselecttwo, \echo, 'option e' ],
        [ \choices_testselecttwo, \foxtrot, 'option f' ],
        [ \choices_testselecttwo, \golf, 'option g' ],
        [ \choices_testselecttwo, \hotel, 'option h' ]
      ])

    test 'language-keyed field appropriately filled' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, 1: \es, _counter: 1 }
        controls: [
          { type: \inputSelectOne, name: \testselect, options: [
            { text: { 0: 'option a' }, val: \alpha },
            { text: { 1: 'opción b' }, val: \bravo },
            { text: { 0: 'option c', 1: 'opción c' }, val: \charlie },
            { val: \delta }
          ] }
        ]
      )

      expect(result[1].data).toEqual([
        [ 'list name', \name, \label::en, \label::es ],
        [ \choices_testselect, \alpha, 'option a', undefined ],
        [ \choices_testselect, \bravo, undefined, 'opción b' ],
        [ \choices_testselect, \charlie, 'option c', 'opción c' ],
        [ \choices_testselect, \delta, undefined, undefined ]
      ])

describe 'complex row generation' ->
  test 'generates begin and end rows for groups' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [{ type: \group, name: \mygroup, children: [] }]
      )

      expect(result[0].data[1]).toEqual([ 'begin group', \mygroup ])
      expect(result[0].data[2]).toEqual([ 'end group' ])

  test 'generates child rows for questions nested in groups' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [{ type: \group, name: \mygroup, children: [
          { type: \inputText, name: \aquestion, label: { 0: 'question one' } },
          { type: \inputText, name: \bquestion, label: { 0: 'question two' } }
        ] }]
      )

      expect(result[0].data).toEqual([
        [ \type, \name, \label::en ],
        [ 'begin group', \mygroup, undefined ],
        [ 'text', \aquestion, 'question one' ],
        [ 'text', \bquestion, 'question two' ],
        [ 'end group' ]
      ])

  test 'groups nest correctly' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [{ type: \group, name: \mygroup, children: [
          { type: \inputText, name: \aquestion, label: { 0: 'question one' } },
          { type: \group, name: \yourgroup, children: [
            { type: \inputText, name: \bquestion, label: { 0: 'question two' } }
          ]}
        ] }]
      )

      expect(result[0].data).toEqual([
        [ \type, \name, \label::en ],
        [ 'begin group', \mygroup, undefined ],
        [ 'text', \aquestion, 'question one' ],
        [ 'begin group', \yourgroup, undefined ],
        [ 'text', \bquestion, 'question two' ],
        [ 'end group' ]
        [ 'end group' ]
      ])

  test 'loop option creates repeats' ->
      result = convert-form(
        metadata:
          activeLanguages: { 0: \en, _counter: 0 }
        controls: [{ type: \group, name: \mygroup, loop: true, children: [] }]
      )

      expect(result[0].data[1]).toEqual([ 'begin repeat', \mygroup ])
      expect(result[0].data[2]).toEqual([ 'end repeat' ])

describe 'settings generation' ->
  test 'generates expected fields and values' ->
    result = gen-settings({ title: \myform })

    expect(result[0]).toEqual([ \form_title, \form_id ])
    expect(result[1][0]).toBe(\myform)
    expect(result[1][1]).toMatch(/build_myform_[0-9]+/)

  test 'uses metadata htitle for form title if provided' ->
    result = gen-settings({ title: \myform, metadata: { htitle: 'override title' } })
    expect(result[1][0]).toBe('override title')

  test 'passes through basic metadata properties' ->
    # do it in two passes to ensure partial generation works:
    result = gen-settings({ title: \myform, metadata: { public_key: 'testkey', submission_url: 'testurl' } })
    expect(result[0][2]).toBe(\public_key)
    expect(result[1][2]).toBe(\testkey)
    expect(result[0][3]).toBe(\submission_url)
    expect(result[1][3]).toBe(\testurl)

    result = gen-settings({ title: \myform, metadata: { instance_name: 'testname' } })
    expect(result[0][2]).toBe(\instance_name)
    expect(result[1][2]).toBe(\testname)

  test 'passes through user-specified version', ->
    result = gen-settings({ title: \myform, metadata: { user_version: 'testversion' } })
    expect(result[0][2]).toBe(\version)
    expect(result[1][2]).toBe(\testversion)

  test 'sanitizes form title for form_id' ->
    result = gen-settings({ title: 'Untitled! Test Form' })
    expect(result[1][1]).toMatch(/build_Untitled-Test-Form_[0-9]+/)

  test 'part of complete workbook generation' ->
    result = convert-form({ title: 'Test Form', metadata: { activeLanguages: { 0: \en, _counter: 0 } }, controls: [] })
    expect(result[2].name).toBe(\settings)
    expect(result[2].data[0]).toEqual([ \form_title, \form_id ])
    expect(result[2].data[1][0]).toBe('Test Form')
    expect(result[2].data[1][1]).toMatch(/build_Test-Form_[0-9]+/)

