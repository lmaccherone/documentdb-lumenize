fs = require('fs')
documentDBUtils = require('documentdb-utils')
{OLAPCube} = require('lumenize')
DocumentClient = require("documentdb").DocumentClient

filterQuery = 'SELECT * FROM Facts WHERE Facts.Priority = 1'
#  filterQuery = null

dimensions = [
  {field: "ProjectHierarchy", type: 'hierarchy'},
  {field: "Priority"}
]

metrics = [
  {field: "Points", f: "sum", as: "Scope"}
]

cubeConfig = {dimensions, metrics}
cubeConfig.keepTotals = true

usingStoredProcedure = () ->

  {cube} = require('./stored-procedures/cube')
  #cube = fs.readFileSync('./stored-procedures/cube.string', 'utf8')

  config =
    databaseID: 'test-stored-procedure'
    collectionID: 'testing-s3'
    storedProcedureID: 'cube'
    storedProcedureJS: cube
    memo: {cubeConfig, filterQuery}
    debug: false

  processResponse = (err, response) ->
    console.log(response.stats)
    cube = OLAPCube.newFromSavedState(response.memo.savedCube)
    console.log(cube.toString(null, null, 'Scope'))
    if err?
      throw new Error(JSON.stringify(err))

    readingDirectly(response.collectionLink)

  documentDBUtils(config, processResponse)

readingDirectly = (collectionLink) ->
  console.time('readingDirectly')
  console.log(collectionLink)
  totalRequestCharges = 0
  client = new DocumentClient(process.env.DOCUMENT_DB_URL, {masterKey: process.env.DOCUMENT_DB_KEY})

  client.queryDocuments(collectionLink, filterQuery, {maxItemCount: 1000}).toArray((err, resources, header) ->
    if err?
      console.log(JSON.stringify(err))
    console.log(resources.length)
    console.log(header)
    console.timeEnd('readingDirectly')
    cube = new OLAPCube(cubeConfig, resources)
    console.log(cube.toString(null, null, 'Scope'))
    console.timeEnd('readingDirectly')
  )

collectionLink = 'dbs/dF0DAA==/colls/dF0DAO918AA=/'

usingStoredProcedure()

#readingDirectly(collectionLink)


