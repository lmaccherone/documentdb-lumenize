documentDBUtils = require('documentdb-utils')
{csvStyleArray_To_ArrayOfMaps, table, OLAPCube} = require('lumenize')

{cube} = require('./stored-procedures/cube')

dimensions = [
  {field: "ProjectHierarchy", type: 'hierarchy'},
  {field: "Priority"}
]

metrics = [
  {field: "Points", f: "sum", as: "Scope"}
]

cubeConfig = {dimensions, metrics}
cubeConfig.keepTotals = true

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'testing-s3'
  storedProcedureID: 'cube'
  storedProcedureJS: cube
  memo: {cubeConfig}
  debug: false

processResponse = (err, response) ->
  console.log(response.stats)
  cube = OLAPCube.newFromSavedState(response.memo.savedCube)
  console.log(cube.toString(null, null, 'Scope'))
  if err?
    throw new Error(JSON.stringify(err))

documentDBUtils(config, processResponse)