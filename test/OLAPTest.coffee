path = require('path')
lumenize = require('lumenize')
DocumentDBMock = require('documentdb-mock')
mock = new DocumentDBMock(path.join(__dirname, '..', 'stored-procedures', 'cube'))

exports.OLAPTest =

  testGroupBy: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {id: 1, value: 100}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

    cubeConfig = {groupBy: 'id', field: "value", f: "sum"}

    mock.package.cube({cubeConfig})

    expectedResult = [
      [ 'id', '_count', 'value_sum' ],
      [ 1, 2, 110 ],
      [ 2, 1, 20 ],
      [ 3, 1, 30 ]
    ]

    test.deepEqual(mock.lastBody.savedCube.cellsAsCSVStyleArray, expectedResult)

    test.done()

  testFilterQuery: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {id: 1, value: 100}
    ]

    cubeConfig = {groupBy: 'id', field: "value", f: "sum"}
    filterQuery = 'SELECT * FROM Facts f WHERE f.id = 1'

    mock.package.cube({cubeConfig, filterQuery})

    expectedResult = [
      [ 'id', '_count', 'value_sum' ],
      [    1,        2,         110 ]
    ]

    test.deepEqual(mock.lastBody.savedCube.cellsAsCSVStyleArray, expectedResult)

    test.done()

  testSimple: (test) ->
    mock.nextResources = [
      {_ProjectHierarchy: [1, 2, 3], Priority: 1, Points: 10},
      {_ProjectHierarchy: [1, 2, 4], Priority: 2, Points: 5 },
      {_ProjectHierarchy: [5]      , Priority: 1, Points: 17},
      {_ProjectHierarchy: [1, 2]   , Priority: 1, Points: 3 },
    ]

    dimensions = [
      {field: "_ProjectHierarchy", type: 'hierarchy'},
      {field: "Priority"}
    ]

    metrics = [
      {field: "Points", f: "sum", as: "Scope"}
    ]

    config = {dimensions, metrics}
    config.keepTotals = true

    mock.package.cube({cubeConfig: config})
    cube = new lumenize.OLAPCube.newFromSavedState(mock.lastBody.savedCube)

    expected = {
      _ProjectHierarchy: null,
      Priority: 1,
      _count: 3,
      Scope: 30
    }

    test.deepEqual(expected, cube.getCell({Priority: 1}))

    expected = {
      _ProjectHierarchy: [ 1 ],
      Priority: null,
      _count: 3,
      Scope: 18
    }
    test.deepEqual(expected, cube.getCell({_ProjectHierarchy: [1]}))

    expected = [null, [1], [1, 2], [1, 2, 3], [1, 2, 4], [5]]
    test.deepEqual(expected, cube.getDimensionValues('_ProjectHierarchy'))

    expected = [null, 1, 2]
    test.deepEqual(expected, cube.getDimensionValues('Priority'))

    expected = '''
          |        || Total |     1     2|
          |==============================|
          |Total   ||    35 |    30     5|
          |------------------------------|
          |[1]     ||    18 |    13     5|
          |[1,2]   ||    18 |    13     5|
          |[1,2,3] ||    10 |    10      |
          |[1,2,4] ||     5 |           5|
          |[5]     ||    17 |    17      |
        '''

    outString = cube.toString('_ProjectHierarchy', 'Priority', 'Scope')
    test.equal(expected, outString)

    test.done()

  testOLAPCube: (test) ->
    aCSVStyle = [
      ['f1', 'f2'         , 'f3', 'f4'],
      ['a' , ['1','2','3'], 7   , 3   ],
      ['b' , ['1','2']    , 70  , 30  ]
    ]

    mock.nextResources = lumenize.csvStyleArray_To_ArrayOfMaps(aCSVStyle)

    dimensions = [
      {field: 'f2', type:'hierarchy'},
      {field: 'f1'}
    ]

    metrics = [
      {field: 'f3', f: 'sum'},
      {field: 'f4', f: 'p50'}
    ]

    config = {dimensions, metrics}
    config.keepTotals = true

    expectedSum = '''
      |              || Total |   "a"   "b"|
      |====================================|
      |Total         ||    77 |     7    70|
      |------------------------------------|
      |["1"]         ||    77 |     7    70|
      |["1","2"]     ||    77 |     7    70|
      |["1","2","3"] ||     7 |     7      |
    '''

    mock.package.cube({cubeConfig: config})
    cube = new lumenize.OLAPCube.newFromSavedState(mock.lastBody.savedCube)

    test.deepEqual(expectedSum, cube.toString(undefined, undefined, 'f3_sum'))

    expected = undefined
    test.deepEqual(expected, cube.getCell({f1: "z"}))

    test.done()

  basicTest: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {id: 1, value: 100}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

    dimensions = [
      {field: "id"}
    ]

    metrics = [
      {field: "value", f: "sum"}
    ]

    cubeConfig = {dimensions, metrics}
    cubeConfig.keepTotals = true

    mock.package.cube({cubeConfig})

    expectedResult = [
      [ 'id', '_count', 'value_sum' ],
      [ 1, 2, 110 ],
      [ null, 4, 160 ],
      [ 2, 1, 20 ],
      [ 3, 1, 30 ]
    ]

    test.deepEqual(mock.lastBody.savedCube.cellsAsCSVStyleArray, expectedResult)

    test.done()

  missingDimensionValueTest: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {id: null, value: 100}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

    dimensions = [
      {field: "id"}
    ]

    metrics = [
      {field: "value", f: "sum"}
    ]

    cubeConfig = {dimensions, metrics}
    cubeConfig.keepTotals = true

    mock.package.cube({cubeConfig})

    expectedResult = [
      [ 'id', '_count', 'value_sum' ],
      [ 1, 1, 10 ],
      [ null, 4, 160 ],
      [ '<missing>', 1, 100 ],
      [ 2, 1, 20 ],
      [ 3, 1, 30 ]
    ]

    test.deepEqual(mock.lastBody.savedCube.cellsAsCSVStyleArray, expectedResult)

    test.done()

  missingDimensionFieldTest: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {value: 100}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

    dimensions = [
      {field: "id"}
    ]

    metrics = [
      {field: "value", f: "sum"}
    ]

    cubeConfig = {dimensions, metrics}
    cubeConfig.keepTotals = true

    mock.package.cube({cubeConfig})

    test.done()

  missingMetricValueTest: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {id: 1, value: null}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

    dimensions = [
      {field: "id"}
    ]

    metrics = [
      {field: "value", f: "sum"}
    ]

    cubeConfig = {dimensions, metrics}
    cubeConfig.keepTotals = true

    mock.package.cube({cubeConfig})

    test.done()

  missingMetricFieldTest: (test) ->
    mock.nextResources = [
      {id: 1, value: 10}
      {id: 1}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

    dimensions = [
      {field: "id"}
    ]

    metrics = [
      {field: "value", f: "sum"}
    ]

    cubeConfig = {dimensions, metrics}
    cubeConfig.keepTotals = true

    mock.package.cube({cubeConfig})

    test.done()
