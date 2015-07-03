generateData = (documentCount) ->

  possibleValues =
    ProjectHierarchy: [
      [1, 2, 3],
      [1, 2, 4],
      [1, 2],
      [5],
      [5, 6]
    ],
    Priority: [1, 2, 3, 4]
    Severity: [1, 2, 3, 4]
    Points: [null, 0.5, 1, 2, 3, 5, 8, 13]
    State: ['Backlog', 'Ready', 'In Progress', 'In Testing', 'Accepted', 'Shipped']

  getIndex = (length) ->
    return Math.floor(Math.random() * length)

  getRandomValue = (possibleValues) ->
    index = getIndex(possibleValues.length)
    return possibleValues[index]

  keys = (key for key, value of possibleValues)

  rows = []
  if getContext?
    collection = getContext().getCollection()

  for i in [1..documentCount]
    row = {}
    for key in keys
      row[key] = getRandomValue(possibleValues[key])
    if getContext?
      accepted = collection.createDocument(collection.getSelfLink(), row)
    else
      rows.push(row)

  if getContext?
    getContext().getResponse().setBody("Successfully inserted #{documentCount} documents!")
  else
    return rows

exports.generateData = generateData
