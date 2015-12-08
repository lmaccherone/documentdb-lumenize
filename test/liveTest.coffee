path = require('path')
{WrappedClient, loadSprocs, loadUDFs, getLinkArray, getLink, async} = require('documentdb-utils')
cube = require('../sprocs/cube')
createSpecificDocuments = require('../node_modules/documentdb-utils/sprocs/createSpecificDocuments')
{OLAPCube} = require('lumenize')


client = null
docsRemaining = 10
docsRetrieved = 0

exports.liveTest =

  setUp: (setUpCallback) ->
    urlConnection = process.env.DOCUMENT_DB_URL
    masterKey = process.env.DOCUMENT_DB_KEY
    auth = {masterKey}
    client = new WrappedClient()
    client.deleteDatabase('dbs/dev-test-database', (err, response) ->
      if err? and err.code isnt 404
        console.dir(err)
        throw new Error("Got error trying to delete dbs/dev-test-database")
      client.createDatabase({id: 'dev-test-database'}, (err, response, headers) ->
        if err?
          console.dir(err)
          throw new Error("Got error creating database")
        databaseLink = response._self
        client.createCollection(databaseLink, {id: '1'}, {offerType: 'S2'}, (err, response, headers) ->
          collectionLink = getLink('dev-test-database', 1)
          async.parallel([
            (callback) ->
              client.upsertStoredProcedure(collectionLink, {id: 'cube', body: cube}, (err, result) ->
                if err?
                  console.log("Error loading cube")
                  console.dir(err)
                  callback(err)
                console.log("local sprocs (cube) loaded for test")
                callback(err, result)
              )
            , (callback) ->
              client.upsertStoredProcedure(collectionLink, {id: 'createSpecificDocuments', body: createSpecificDocuments}, (err, result) ->
                if err?
                  callback(err)
                console.log("createSpecificDocuments sproc loaded for test")
                sprocLink = getLink(collectionLink, 'createSpecificDocuments')
                documents = [
                  {ProjectHierarchy: [1, 2, 3], Priority: 1, Points: 10},
                  {ProjectHierarchy: [1, 2, 4], Priority: 2, Points: 5 },
                  {ProjectHierarchy: [5]      , Priority: 1, Points: 17},
                  {ProjectHierarchy: [1, 2]   , Priority: 1, Points: 3 },
                ]
                client.executeStoredProcedure(sprocLink, {documents}, (err, response) ->
                  if err?
                    callback(err)
                  console.log("Documents created for test")
                  callback(err, response)
                )
              )
          ],
            (err, results) ->
              if err?
                console.dir(err)
                throw new Error("Got error trying to load sprocs or in call to createSpecificDocuments sproc in test setup")
              console.log("Test setup done")
              setUpCallback()
          )
        )
      )
    )

  cubeTest: (test) ->
    dimensions = [
      {field: "ProjectHierarchy", type: 'hierarchy'},
      {field: "Priority"}
    ]
    metrics = [
      {field: "Points", f: "sum", as: "Scope"}
    ]
    cubeConfig = {dimensions: dimensions, metrics: metrics}
    cubeConfig.keepTotals = true
    filterQuery = 'SELECT * FROM Facts f WHERE f.Priority = 1'
    memo = {cubeConfig, filterQuery}
    sprocLink = getLink('dev-test-database', 1, 'cube')
    client.executeStoredProcedure(sprocLink, memo, (err, response) ->
      if err?
        console.dir(err)
        throw new Error("Got unexpected error in cubeTest")

      cube = OLAPCube.newFromSavedState(response.savedCube)
      expected = '''
        |        || Total |     1|
        |========================|
        |Total   ||     3 |     3|
        |------------------------|
        |[1]     ||     2 |     2|
        |[1,2]   ||     2 |     2|
        |[1,2,3] ||     1 |     1|
        |[5]     ||     1 |     1|
      '''
      test.equal(cube.toString(), expected)
      delete memo.filterQuery
      client.executeStoredProcedure(sprocLink, memo, (err, response) ->
        if err?
          console.dir(err)
          throw new Error("Got unexpected error in cubeTest")

        cube = OLAPCube.newFromSavedState(response.savedCube)
        expected = '''
          |        || Total |     1     2|
          |==============================|
          |Total   ||     4 |     3     1|
          |------------------------------|
          |[1]     ||     3 |     2     1|
          |[1,2]   ||     3 |     2     1|
          |[1,2,3] ||     1 |     1      |
          |[1,2,4] ||     1 |           1|
          |[5]     ||     1 |     1      |
        '''
        test.equal(cube.toString(), expected)

        test.done()
      )
    )

  tearDown: (callback) ->
    f = () ->
      client.deleteDatabase('dbs/dev-test-database', () ->
        callback()
      )
    setTimeout(f, 500)