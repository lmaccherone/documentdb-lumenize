documentDBUtils = require('documentdb-utils')
{csvStyleArray_To_ArrayOfMaps, table, OLAPCube} = require('lumenize')

{cube} = require('./cube')

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'testing-s3'
  storedProcedureID: 'cube'
  storedProcedureJS: cube
  memo: {}
  debug: true

processResponse = (err, response) ->
  console.log(response.stats)
  cube = OLAPCube.newFromSavedState(response.memo.savedCube)
  console.log(cube.toString())
  if err?
    throw new Error(JSON.stringify(err))

documentDBUtils(config, processResponse)