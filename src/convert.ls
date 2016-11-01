{ is-type, map, filter, foldl, join, flatten } = require(\prelude-ls)
{ keys, empty } = require(\prelude-ls).Obj
deepcopy = require(\deepcopy)
{ build } = require(\node-xlsx).default

# util.
is-nonsense = (value) -> !value? or (value is '') or (is-type(\Object, value) and empty(value))
expr-value = (value) ->
  | value is null             => "''"
  | value |> is-type(\String) => "'#value'"
  | otherwise                 => value

# conversion constants.
survey-fields = <[ type name label hint required read_only default constraint constraint_message relevant calculation appearance ]>
choices-fields = [ 'list name', \name, \label ]

multilingual-fields = <[ label hint constraint_message ]> # these fields have ::lang syntax/support.
prune-false = <[ required read_only range length ]> # these fields default to 'no', so just leave them out for a cleaner output.

fieldname-conversion =
  defaultValue: \default
  relevance: \relevant
  calculate: \calculation
  invalidText: \constraint_message
  readOnly: \read_only

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
  'Device Id': \deviceid
  'Start Time': \start
  'End Time': \end
  'Today': \today
  'Username': \username
  'Subscriber ID': \subscriberid
  'SIM Serial': \simserial
  'Phone Number': \phonenumber

# make unit testing easier.
new-context = -> { seen-fields: {}, choices: {}, warnings: [] }

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
    question.constraint = (question.constraint ? []) ++
      ". >#{if range.minInclusive is true then \= else ''} #{expr-value(range.min)}" ++
      ". <#{if range.maxInclusive is true then \= else ''} #{expr-value(range.max)}"
  # convert constraint field back into an expression.
  if question.constraint.length is 0
    delete question.constraint
  else
    question.constraint = question.constraint |> map(-> "(#it)") |> join(' and ')

  # field-list appearance.
  if (delete question.fieldList) is true
    question.appearance = \field-list

  # deal with choices. life is hard.
  if question.options?
    context.warnings ++= [ "Multiple choice lists have the ID '#choice-id'. The last one encountered is used." ] if context.choices[choice-id]?
    context.choices[choice-id] = (delete question.options)

  # if date, we may need to apply an appearance.
  if question.type is \inputDate
    question.appearance = date-kind-conversion[question.kind] if date-type-conversion[question.kind]?

  # massage the type.
  question.type =
    if question.type is \inputNumeric
      ((delete question.kind) ? \integer).toLowerCase()
    else if question.type is \inputMedia
      ((delete question.kind) ? \image).toLowerCase()
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

  # boolean value conversion. do this near the end to prevent confusion.
  for key, value of question when value is true or value is false
    question[key] = if value is true then \yes else \no

  # mark the schema fields we've seen.
  for key of question
    context.seen-fields[key] = true

  # xlsform doesn't support custom xpath bindings. warn about lossiness.
  if (destination = delete question.destination)?
    context.warnings ++= [ "A custom xpath destination of '#destination' was specified. XLSForm does not support this feature and the declaration has been dropped." ]

  # recurse.
  if question.children?
    question.children = [ convert-question(child, context, prefix) for child in question.children ]

  # return. context is mutated (:/) so does not need to be returned.
  question

# the main show.
convert-form = (form) ->
  # convert build question data to intermediate xls-json form.
  context = new-context()
  intermediate = [ convert-question(question, context) for question in form.controls ]

  # pull apart some context for easy referencing.
  languages = form.metadata.active-languages
  { seen-fields, choices, warnings } = context

  # determine final schema for each sheet.
  expand-languages = (field) -> if field in multilingual-fields then [ "#field::#language" for language in languages ] else [ field ]
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

  # choices serialize straight out.
  choices-rows = [ [ name, entry.val ] ++ gen-lang(entry.text) for name, entries of choices for entry in entries ]

  # return sheets.
  [
    { name: \survey, data: ([ survey-schema ] ++ survey-rows) },
    { name: \choices, data: ([ choices-schema ] ++ choices-rows) },
    { name: \warnings, data: [ [[ warning ]] for warning in ([ 'message' ] ++ (warnings ? [ 'No warnings; everything looked fine.' ])) ] }
  ]

# takes sheets, streams xlsx.
serialize-form = (stream, sheets) -->
  stream.setHeader(\Content-Type, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
  stream.setHeader(\Content-Disposition, 'fieldname="converted.xlsx"')
  stream.write(build(sheets))
  stream.statusCode = 200
  stream.end()

# export everything for unit testing; most people should only need convert-form/serialize-form.
module.exports = { new-context, convert-question, convert-form, serialize-form }

