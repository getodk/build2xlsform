{ is-type, map, filter, foldl, join, flatten } = require(\prelude-ls)
{ keys, empty } = require(\prelude-ls).Obj
deepcopy = require(\deepcopy)
{ write-file } = require(\fs)
{ build } = require(\node-xlsx).default

# util.
is-nonsense = (value) -> !value? or (value is '') or (is-type(\Object, value) and empty(value))
expr-value = (value) ->
  | value is null             => "''"
  | value |> is-type(\String) => "'#value'"
  | otherwise                 => value

# conversion constants.
survey-fields = <[ type name label hint guidance_hint required required_message read_only default constraint constraint_message relevant calculation choice_filter parameters appearance ]>
choices-fields = [ 'list name', \name, \label ]

multilingual-fields = <[ label hint guidance_hint required_message constraint_message ]> # these fields have ::lang syntax/support.
prune-false = <[ required read_only range length count ]> # these fields default to 'no', so just leave them out for a cleaner output.

fieldname-conversion =
  defaultValue: \default
  relevance: \relevant
  calculate: \calculation
  invalidText: \constraint_message
  readOnly: \read_only
  requiredText: \required_message
  guidance: \guidance_hint

type-conversion = {} # currently unused

choice-type-conversion =
  inputSelectOne: \select_one
  inputSelectMany: \select_multiple

date-type-conversion =
  'Full Date and Time': \dateTime
  'Full Date': \date
  'Year and Month': \date
  'Year': \date

date-kind-conversion =
  'Year and Month': \month-year
  'Year': \year

location-type-conversion =
  'Point': \geopoint
  'Path': \geotrace
  'Shape': \geoshape

metadata-type-conversion =
  'Device ID': \deviceid
  'Start Time': \start
  'End Time': \end
  'Today': \today
  'Username': \username
  'Subscriber ID': \subscriberid
  'SIM Serial': \simserial
  'Phone Number': \phonenumber
  'Start Geopoint': \start-geopoint

appearance-noops = [ 'Default (GPS)', 'Default' ]

appearance-conversion =
  'Show Map (GPS)': \maps
  'Manual (No GPS)': \placement-map
  'Minimal (spinner)': \minimal
  'Table': \label
  'Horizontal Layout': \horizontal

range-appearance-conversion =
  'Vertical Slider': \vertical
  'Picker': \picker

media-type-conversion =
  'Image': \image
  'New Image': \image
  'Selfie': \image
  'Annotate': \image
  'Draw': \image
  'Signature': \image
  'Audio': \audio
  'Video': \video
  'Selfie Video': \video
media-appearance-conversion =
  'New Image': \new
  'Signature': \signature
  'Annotate': \annotate
  'Draw': \draw
  'Selfie': \new-front
  'Selfie Video': \new-front

# make unit testing easier.
new-context = -> { seen-fields: {}, choices: {}, warnings: [] }

# creates a range expression.
gen-range = (type, range, self = \.) ->
  result = []
  unless is-nonsense(range.min)
    min = if type is \inputDate then "date(#{expr-value(range.min)})" else expr-value(range.min)
    result.push("#self >#{if range.minInclusive is true then \= else ''} #{min}")
  unless is-nonsense(range.max)
    max = if type is \inputDate then "date(#{expr-value(range.max)})" else expr-value(range.max)
    result.push("#self <#{if range.maxInclusive is true then \= else ''} #{max}")
  result

# returns an intermediate-formatted question clone (purely functional), but mutates context.
convert-question = (question, context, prefix = []) ->
  # full clone.
  question = deepcopy(question)

  # we don't need the prefix so much as our own id.
  prefix ++= [ question.name ]
  choice-id = "choices_#{prefix.join(\_)}"

  # convert some field names.
  for frm, too of fieldname-conversion when question[frm]?
    question[too] = delete question[frm]

  # prune strict-false fields where meaningless.
  for key, value of question when value is false and key in prune-false
    delete question[key]

  # prune empty fields.
  for key, value of question
    delete question[key] if is-nonsense(value)

  ## merge in convenience constraint logic definitions:
  # convert constraint field to array.
  question.constraint = if question.constraint? then [ question.constraint ] else []
  # merge text length logic.
  if (length = delete question.length)?
    question.constraint = (question.constraint ? []) ++ "regex(., \"^.{#{length.min},#{length.max}}$\")"
  # merge number/date range.
  if (range = delete question.range)?
    question.constraint = (question.constraint ? []) ++ gen-range(question.type, range)
  # merge select multiple choice count range.
  if (count = delete question.count)?
    question.constraint = (question.constraint ? []) ++ gen-range(question.type, count, 'count-selected(.)')
  # convert constraint field back into an expression.
  if question.constraint.length is 0
    delete question.constraint
  else
    question.constraint = question.constraint |> map(-> "(#it)") |> join(' and ')

  ## merge in convenience relevant logic definitions:
  if (successor-relevance = delete context.successor-relevance)?
    unless is-nonsense(successor-relevance)
      question.relevant = (question.relevant ? []) ++ [ successor-relevance ] |> map(-> "(#it)") |> (.join(' and '))

  ## drop successor information into context:
  if (other = delete question.other)?
    context.successor-relevance = other |> map(-> "selected(#{question.name}, '#it')") |> join(' or ')

  # deal with cascades.
  if (question.cascading is true) or context.cascade?
    context.cascade ?= []

    # add a choice filter column value.
    question.choice_filter = [ "#name = ${#name}" for name in context.cascade ].join(' and ')

    # munge our options to have cascade dicts rather than arrays.
    for option in question.options
      option.cascade = { [ context.cascade[idx], value ] for value, idx in option.cascade }

    # push our context now that we are done. drop the whole thing if we are at the tail.
    context.cascade.push(question.name)
    if question.cascading isnt true
      delete context.cascade
    delete question.cascading

  # deal with choices. life is hard.
  if question.options?
    context.warnings ++= [ "Multiple choice lists have the ID '#choice-id'. The last one encountered is used." ] if context.choices[choice-id]?
    context.choices[choice-id] = (delete question.options)

  # appearance value-massaging.
  if question.appearance in appearance-noops
    delete question.appearance
  if appearance-conversion[question.appearance]?
    question.appearance = appearance-conversion[delete question.appearance]

  # if date, we may need to apply an appearance.
  if question.type is \inputDate
    question.appearance = date-kind-conversion[question.kind] if date-type-conversion[question.kind]?

  # if media, we may need to apply an appearance.
  if question.type is \inputMedia and media-appearance-conversion[question.kind]?
    question.appearance = media-appearance-conversion[question.kind]

  # field-list appearance.
  if (delete question.fieldList) is true
    question.appearance = \field-list

  # massage the type.
  question.type =
    if question.type is \inputNumeric
      if !question.appearance? or question.appearance is \Textbox
        delete question.appearance
        ((delete question.kind) ? \integer).toLowerCase()
      else
        \range
    else if question.type is \inputMedia
      media-type-conversion[(delete question.kind) ? 'Image']
    else if question.type is \inputDate
      date-type-conversion[(delete question.kind) ? 'Full Date']
    else if question.type is \inputLocation
      location-type-conversion[(delete question.kind) ? 'Point']
    else if question.type is \metadata
      metadata-type-conversion[(delete question.kind) ? 'Device ID']
    else if question.type is \group
      if (delete question.loop) is true then \repeat else \group
    else if question.type of choice-type-conversion
      "#{choice-type-conversion[question.type]} #choice-id"
    else if question.type of type-conversion
      type-conversion[question.type]
    else
      question.type.slice(5).toLowerCase()

  # range parameters.
  if question.type is \range
    select-range = (delete question.selectRange)
    question.parameters = { start: select-range?.min, end: select-range?.max, step: (delete question.selectStep) }
    question.appearance = range-appearance-conversion[delete question.appearance]
    if question.sliderTicks is false
      question.appearance = ((question.appearance ? '') + ' no-ticks').trim()

  # boolean value conversion. do this near the end to prevent confusion.
  for key, value of question when value is true or value is false
    question[key] = if value is true then \yes else \no

  # convert the parameters field.
  if question.parameters?
    question.parameters = ([ "#key=#{JSON.stringify(value)}" for key, value of question.parameters ]).join(' ')

  # mark the schema fields we've seen.
  for key of question
    context.seen-fields[key] = true

  # xlsform doesn't support custom xpath bindings. warn about lossiness.
  if (destination = delete question.destination)?
    context.warnings ++= [ "A custom xpath destination of '#destination' was specified. XLSForm does not support this feature and the declaration has been dropped." ]

  # recurse.
  if question.children?
    question.children = [ convert-question(child, context, prefix) for child in question.children ]
    delete context.successor-relevance

  # return. context is mutated (:/) so does not need to be returned.
  question

with-column = (input, header, value) -> [ input.0 ++ [ header ], input.1 ++ [ value ] ]
gen-settings = (form) ->
  result = [ [], [] ]

  result = with-column(result, \form_title, if is-nonsense(form.metadata?.htitle) then form.title else form.metadata?.htitle)
  result = with-column(result, \form_id, "#{form.title?.replace(/([^a-z0-9]+)/ig, '-')}")

  for attr in [ \public_key, \submission_url, \instance_name ] when form.metadata?[attr]?
    result = with-column(result, attr, form.metadata[attr])

  if form.metadata?.user_version
    result = with-column(result, \version, form.metadata.user_version)
  else
    result = with-column(result, \version, Math.floor((new Date()).getTime() / 1000))

  result

# the main show.
convert-form = (form) ->
  # convert build question data to intermediate xls-json form.
  context = new-context()
  intermediate = [ convert-question(question, context) for question in form.controls ]

  # pull apart some context for easy referencing.
  languages = form.metadata.active-languages |> keys |> filter(-> not /^_/.test(it))
  language-names = { [ language, form.metadata.active-languages[language] ] for language in languages }
  { seen-fields, choices, warnings } = context

  # determine final schema for each sheet.
  expand-languages = (field) -> if field in multilingual-fields then [ "#field::#{language-names[language]}" for language in languages ] else [ field ]
  gen-schema = (seen, all) -> all |> filter (in seen) |> foldl(((fields, field) -> fields ++ expand-languages(field)), [])
  survey-schema = gen-schema(keys(seen-fields), survey-fields)
  choices-schema = gen-schema(choices-fields, choices-fields)

  # output util.
  gen-lang = (obj) -> [ obj?[language] for language in languages ] # ? to absorb null values (but we still have to generate n nulls)

  # survey is a bit annoying; languages screw up the schema and nesting screws up row output a bit.
  survey-simple-fields = survey-fields |> filter (in keys(seen-fields)) # get a version without language blown out.
  gen-rows = (question) ->
    if question |> is-type(\Array)
      question |> foldl(((rows, question) -> rows ++ gen-rows(question)), [])
    else if question.type in [ \group, \repeat ]
      gen-rows(question with { type: "begin #{question.type}" }) ++ gen-rows(question.children) ++ [[ "end #{question.type}" ]]
    else
      [ [ (if field in multilingual-fields then gen-lang(question[field]) else question[field]) for field in survey-simple-fields ] |> flatten ]
  survey-rows = gen-rows(intermediate)

  # choices might gain columns if cascades are involved.
  additional-choice-cols = []
  for _, entries of choices when entries[0]?.cascade?
    for key of entries[0].cascade when key not in additional-choice-cols
      additional-choice-cols.push(key)
  choices-schema ++= additional-choice-cols

  # once we know the additional fields we can send them all out.
  pull-cascade-values = (entry) -> [ entry.cascade[col] for col in additional-choice-cols ]
  choices-rows = [ [ name, entry.val ] ++ gen-lang(entry.text) ++ pull-cascade-values(entry) for name, entries of choices for entry in entries ]

  # return sheets.
  [
    { name: \survey, data: ([ survey-schema ] ++ survey-rows) },
    { name: \choices, data: ([ choices-schema ] ++ choices-rows) },
    { name: \settings, data: gen-settings(form) },
    { name: \warnings, data: [ [[ warning ]] for warning in ([ 'message' ] ++ (warnings ? [ 'No warnings; everything looked fine.' ])) ] }
  ]

# takes sheets, streams xlsx.
serialize-form = (stream, sheets) -->
  stream.setHeader(\Content-Type, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
  stream.setHeader(\Content-Disposition, 'fieldname="converted.xlsx"')
  stream.write(build(sheets))
  stream.statusCode = 200
  stream.end()

# takes sheets, writes .xlsx.
write-form = (path, sheets, callback) --> write-file(path, build(sheets), callback)

# export everything for unit testing; most people should only need convert-form/serialize-form.
module.exports = { new-context, convert-question, convert-form, gen-settings, serialize-form, write-form }

