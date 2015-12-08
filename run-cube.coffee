fs = require('fs')
{WrappedClient} = require('documentdb-utils')
{OLAPCube} = require('lumenize')

{cube} = require('./sprocs/cube')
#cube = fs.readFileSync('./sprocs/cube.string', 'utf8')

dimensions = [
  {field: "ProjectHierarchy", type: 'hierarchy'},
  {field: "Priority"}
]

metrics = [
  {field: "Points", f: "sum", as: "Scope"}
]

cubeConfig = {dimensions, metrics}
cubeConfig.keepTotals = true

#filterQuery = 'SELECT * FROM Facts WHERE Facts.Priority = 1'
filterQuery = null

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'testing-s3'
  storedProcedureID: 'cube'
  storedProcedureJS: cube
  memo: {cubeConfig, filterQuery}
  debug: true

processResponse = (err, response) ->
  console.log(response.stats)
  cube = OLAPCube.newFromSavedState(response.memo.savedCube)
  console.log(cube.toString(null, null, '_count'))
  if err?
    throw new Error(JSON.stringify(err))

documentDBUtils(config, processResponse)