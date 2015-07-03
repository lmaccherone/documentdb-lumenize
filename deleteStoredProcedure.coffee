documentDBUtils = require('documentdb-utils')

config =
  databaseID: 'test-stored-procedure'
  collectionID: 'testing-s3'
  storedProcedureID: 'cube'
  debug: true

processResponse = (err, response) ->
  if err?
    console.dir(err)
    throw new Error(err)

  console.log(response.stats)
  console.log(response.memo)

documentDBUtils(config, processResponse)