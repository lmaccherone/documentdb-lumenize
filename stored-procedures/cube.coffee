cube = (memo) ->

# utils

  utils = {}

  utils.assert = (exp, message) ->
    if (!exp)
      throw new Error(message)

  # Uses the properties of obj1, so will still match if obj2 has extra properties.
  utils.match = (obj1, obj2) ->
    for key, value of obj1
      if (value != obj2[key])
        return false
    return true

  utils.exactMatch = (a, b) ->
    return true if a is b
    atype = typeof(a);
    btype = typeof(b)
    return false if atype isnt btype
    return false if (!a and b) or (a and !b)
    return false if atype isnt 'object'
    return false if a.length and (a.length isnt b.length)
    return false for key, val of a when !(key of b) or not exactMatch(val, b[key])
    return true

  # At the top level, it will match even if obj1 is missing some elements that are in obj2, but at the lower levels, it must be an exact match.
  utils.filterMatch = (obj1, obj2) ->
    unless type(obj1) is 'object' and type(obj2) is 'object'
      throw new Error('obj1 and obj2 must both be objects when calling filterMatch')
    for key, value of obj1
      if not exactMatch(value, obj2[key])
        return false
    return true

  utils.trim = (val) ->
    return if String::trim? then val.trim() else val.replace(/^\s+|\s+$/g, "")

  utils.startsWith = (bigString, potentialStartString) ->
    return bigString.substring(0, potentialStartString.length) == potentialStartString

  utils.isArray = (a) ->
    return Object.prototype.toString.apply(a) == '[object Array]'

  utils.type = do ->  # from http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
    classToType = {}
    for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
      classToType["[object " + name + "]"] = name.toLowerCase()

    (obj) ->
      strType = Object::toString.call(obj)
      classToType[strType] or "object"

  utils.clone = (obj) ->
    if not obj? or typeof obj isnt 'object'
      return obj

    if obj instanceof Date
      return new Date(obj.getTime())

    if obj instanceof RegExp
      flags = ''
      flags += 'g' if obj.global?
      flags += 'i' if obj.ignoreCase?
      flags += 'm' if obj.multiline?
      flags += 'y' if obj.sticky?
      return new RegExp(obj.source, flags)

    newInstance = new obj.constructor()

    for key of obj
      newInstance[key] = utils.clone(obj[key])

    return newInstance

  utils.keys = Object.keys or (obj) ->
    return (key for key, val of obj)

  utils.values = (obj) ->
    return (val for key, val of obj)

  utils.compare = (a, b) ->  # Used for sorting any type
    if a is null
      return 1
    if b is null
      return -1
    switch type(a)
      when 'number', 'boolean', 'date'
        return b - a
      when 'array'
        for value, index in a
          if b.length - 1 >= index and value < b[index]
            return 1
          if b.length - 1 >= index and value > b[index]
            return -1
        if a.length < b.length
          return 1
        else if a.length > b.length
          return -1
        else
          return 0
      when 'object', 'string'
        aString = JSON.stringify(a)
        bString = JSON.stringify(b)
        if aString < bString
          return 1
        else if aString > bString
          return -1
        else
          return 0
      else
        throw new Error("Do not know how to sort objects of type #{utils.type(a)}.")


# dataTransform

  csvStyleArray_To_ArrayOfMaps = (csvStyleArray, rowKeys) ->
    ###
    @method csvStyleArray_To_ArrayOfMaps
    @param {Array[]} csvStyleArray The first row is usually the list of column headers but if not, you can
      provide your own such list in the second parameter
    @param {String[]} [rowKeys] specify the column headers like `['column1', 'column2']`. If not provided, it will use
      the first row of the csvStyleArray
    @return {Object[]}

    `csvStyleArry_To_ArryOfMaps` is a convenience function that will convert a csvStyleArray like:

        {csvStyleArray_To_ArrayOfMaps} = require('../')

        csvStyleArray = [
          ['column1', 'column2'],
          [1         , 2       ],
          [3         , 4       ],
          [5         , 6       ]
        ]

    to an Array of Maps like this:

        console.log(csvStyleArray_To_ArrayOfMaps(csvStyleArray))

        # [ { column1: 1, column2: 2 },
        #   { column1: 3, column2: 4 },
        #   { column1: 5, column2: 6 } ]
    `
    ###
    arrayOfMaps = []
    if rowKeys?
      i = 0
    else
      rowKeys = csvStyleArray[0]
      i = 1
    tableLength = csvStyleArray.length
    while i < tableLength
      inputRow = csvStyleArray[i]
      outputRow = {}
      for key, index in rowKeys
        outputRow[key] = inputRow[index]
      arrayOfMaps.push(outputRow)
      i++
    return arrayOfMaps

  arrayOfMaps_To_CSVStyleArray = (arrayOfMaps, keys) ->
    ###
    @method arrayOfMaps_To_CSVStyleArray
    @param {Object[]} arrayOfMaps
    @param {Object} [keys] If not provided, it will use the first row and get all fields
    @return {Array[]} The first row will be the column headers

    `arrayOfMaps_To_CSVStyleArray` is a convenience function that will convert an array of maps like:

        {arrayOfMaps_To_CSVStyleArray} = require('../')

        arrayOfMaps = [
          {column1: 10000, column2: 20000},
          {column1: 30000, column2: 40000},
          {column1: 50000, column2: 60000}
        ]

    to a CSV-style array like this:

        console.log(arrayOfMaps_To_CSVStyleArray(arrayOfMaps))

        # [ [ 'column1', 'column2' ],
        #   [ 10000, 20000 ],
        #   [ 30000, 40000 ],
        #   [ 50000, 60000 ] ]
    `
    ###
    if arrayOfMaps.length == 0
      return []
    csvStyleArray = []
    outRow = []
    unless keys?
      keys = []
      for key, value of arrayOfMaps[0]
        keys.push(key)
    csvStyleArray.push(keys)

    for inRow in arrayOfMaps
      outRow = []
      for key in keys
        outRow.push(inRow[key])
      csvStyleArray.push(outRow)
    return csvStyleArray


# functions

  _populateDependentValues = (values, dependencies, dependentValues = {}, prefix = '') ->
    out = {}
    for d in dependencies
      if d == 'count'
        if prefix == ''
          key = 'count'
        else
          key = '_count'
      else
        key = prefix + d
      unless dependentValues[key]?
        dependentValues[key] = functions[d](values, undefined, undefined, dependentValues, prefix)
      out[d] = dependentValues[key]
    return out

  ###
  @method sum
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The sum of the values
  ###

  ###
  @class functions

  Rules about dependencies:

    * If a function can be calculated incrementally from an oldResult and newValues, then you do not need to specify dependencies
    * If a funciton can be calculated from other incrementally calculable results, then you need only specify those dependencies
    * If a function needs the full list of values to be calculated (like percentile coverage), then you must specify 'values'
    * To support the direct passing in of OLAP cube cells, you can provide a prefix (field name) so the key in dependentValues
      can be generated
    * 'count' is special and does not use a prefix because it is not dependent up a particular field
    * You should calculate the dependencies before you calculate the thing that is depedent. The OLAP cube does some
      checking to confirm you've done this.
  ###
  functions = {}

  functions.sum = (values, oldResult, newValues) ->
    if oldResult?
      temp = oldResult
      tempValues = newValues
    else
      temp = 0
      tempValues = values
    for v in tempValues
      temp += v
    return temp

  ###
  @method product
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The product of the values
  ###
  functions.product = (values, oldResult, newValues) ->
    if oldResult?
      temp = oldResult
      tempValues = newValues
    else
      temp = 1
      tempValues = values
    for v in tempValues
      temp = temp * v
    return temp

  ###
  @method sumSquares
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The sum of the squares of the values
  ###
  functions.sumSquares = (values, oldResult, newValues) ->
    if oldResult?
      temp = oldResult
      tempValues = newValues
    else
      temp = 0
      tempValues = values
    for v in tempValues
      temp += v * v
    return temp

  ###
  @method sumCubes
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The sum of the cubes of the values
  ###
  functions.sumCubes = (values, oldResult, newValues) ->
    if oldResult?
      temp = oldResult
      tempValues = newValues
    else
      temp = 0
      tempValues = values
    for v in tempValues
      temp += v * v * v
    return temp


  ###
  @method lastValue
  @static
  @param {Number[]} [values] Must either provide values or newValues
  @param {Number} [oldResult] Not used. It is included to make the interface consistent.
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The last value
  ###
  functions.lastValue = (values, oldResult, newValues) ->
    if newValues?
      return newValues[newValues.length - 1]
    return values[values.length - 1]

  ###
  @method firstValue
  @static
  @param {Number[]} [values] Must either provide values or oldResult
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] Not used. It is included to make the interface consistent.
  @return {Number} The first value
  ###
  functions.firstValue = (values, oldResult, newValues) ->
    if oldResult?
      return oldResult
    return values[0]

  ###
  @method count
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The length of the values Array
  ###
  functions.count = (values, oldResult, newValues) ->
    if oldResult?
      return oldResult + newValues.length
    return values.length

  ###
  @method min
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The minimum value or null if no values
  ###
  functions.min = (values, oldResult, newValues) ->
    if oldResult?
      return functions.min(newValues.concat([oldResult]))
    if values.length == 0
      return null
    temp = values[0]
    for v in values
      if v < temp
        temp = v
    return temp

  ###
  @method max
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Number} The maximum value or null if no values
  ###
  functions.max = (values, oldResult, newValues) ->
    if oldResult?
      return functions.max(newValues.concat([oldResult]))
    if values.length == 0
      return null
    temp = values[0]
    for v in values
      if v > temp
        temp = v
    return temp

  ###
  @method values
  @static
  @param {Object[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Array} All values (allows duplicates). Can be used for drill down.
  ###
  functions.values = (values, oldResult, newValues) ->
    if oldResult?
      return oldResult.concat(newValues)
    return values
  #  temp = []
  #  for v in values
  #    temp.push(v)
  #  return temp

  ###
  @method uniqueValues
  @static
  @param {Object[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] for incremental calculation
  @param {Number[]} [newValues] for incremental calculation
  @return {Array} Unique values. This is good for generating an OLAP dimension or drill down.
  ###
  functions.uniqueValues = (values, oldResult, newValues) ->
    temp = {}
    if oldResult?
      for r in oldResult
        temp[r] = null
      tempValues = newValues
    else
      tempValues = values
    temp2 = []
    for v in tempValues
      temp[v] = null
    for key, value of temp
      temp2.push(key)
    return temp2

  ###
  @method average
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] not used by this function but included so all functions have a consistent signature
  @param {Number[]} [newValues] not used by this function but included so all functions have a consistent signature
  @param {Object} [dependentValues] If the function can be calculated from the results of other functions, this allows
    you to provide those pre-calculated values.
  @return {Number} The arithmetic mean
  ###
  functions.average = (values, oldResult, newValues, dependentValues, prefix) ->
    {count, sum} = _populateDependentValues(values, functions.average.dependencies, dependentValues, prefix)
    return sum / count

  functions.average.dependencies = ['count', 'sum']

  ###
  @method errorSquared
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] not used by this function but included so all functions have a consistent signature
  @param {Number[]} [newValues] not used by this function but included so all functions have a consistent signature
  @param {Object} [dependentValues] If the function can be calculated from the results of other functions, this allows
    you to provide those pre-calculated values.
  @return {Number} The error squared
  ###
  functions.errorSquared = (values, oldResult, newValues, dependentValues, prefix) ->
    {count, sum} = _populateDependentValues(values, functions.errorSquared.dependencies, dependentValues, prefix)
    mean = sum / count
    errorSquared = 0
    for v in values
      difference = v - mean
      errorSquared += difference * difference
    return errorSquared

  functions.errorSquared.dependencies = ['count', 'sum']

  ###
  @method variance
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] not used by this function but included so all functions have a consistent signature
  @param {Number[]} [newValues] not used by this function but included so all functions have a consistent signature
  @param {Object} [dependentValues] If the function can be calculated from the results of other functions, this allows
    you to provide those pre-calculated values.
  @return {Number} The variance
  ###
  functions.variance = (values, oldResult, newValues, dependentValues, prefix) ->
    {count, sum, sumSquares} = _populateDependentValues(values, functions.variance.dependencies, dependentValues, prefix)
    return (count * sumSquares - sum * sum) / (count * (count - 1))

  functions.variance.dependencies = ['count', 'sum', 'sumSquares']

  ###
  @method standardDeviation
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] not used by this function but included so all functions have a consistent signature
  @param {Number[]} [newValues] not used by this function but included so all functions have a consistent signature
  @param {Object} [dependentValues] If the function can be calculated from the results of other functions, this allows
    you to provide those pre-calculated values.
  @return {Number} The standard deviation
  ###
  functions.standardDeviation = (values, oldResult, newValues, dependentValues, prefix) ->
    return Math.sqrt(functions.variance(values, oldResult, newValues, dependentValues, prefix))

  functions.standardDeviation.dependencies = functions.variance.dependencies

  ###
  @method percentileCreator
  @static
  @param {Number} p The percentile for the resulting function (50 = median, 75, 99, etc.)
  @return {Function} A function to calculate the percentile

  When the user passes in `p<n>` as an aggregation function, this `percentileCreator` is called to return the appropriate
  percentile function. The returned function will find the `<n>`th percentile where `<n>` is some number in the form of
  `##[.##]`. (e.g. `p40`, `p99`, `p99.9`).

  There is no official definition of percentile. The most popular choices differ in the interpolation algorithm that they
  use. The function returned by this `percentileCreator` uses the Excel interpolation algorithm which differs from the NIST
  primary method. However, NIST lists something very similar to the Excel approach as an acceptible alternative. The only
  difference seems to be for the edge case for when you have only two data points in your data set. Agreement with Excel,
  NIST's acceptance of it as an alternative (almost), and the fact that it makes the most sense to me is why this approach
  was chosen.

  http://en.wikipedia.org/wiki/Percentile#Alternative_methods

  Note: `median` is an alias for p50. The approach chosen for calculating p50 gives you the
  exact same result as the definition for median even for edge cases like sets with only one or two data points.

  ###
  functions.percentileCreator = (p) ->
    f = (values, oldResult, newValues, dependentValues, prefix) ->
      unless values?
        {values} = _populateDependentValues(values, ['values'], dependentValues, prefix)
      sortfunc = (a, b) ->
        return a - b
      vLength = values.length
      values.sort(sortfunc)
      n = (p * (vLength - 1) / 100) + 1
      k = Math.floor(n)
      d = n - k
      if n == 1
        return values[1 - 1]
      if n == vLength
        return values[vLength - 1]
      return values[k - 1] + d * (values[k] - values[k - 1])
    f.dependencies = ['values']
    return f

  ###
  @method median
  @static
  @param {Number[]} [values] Must either provide values or oldResult and newValues
  @param {Number} [oldResult] not used by this function but included so all functions have a consistent signature
  @param {Number[]} [newValues] not used by this function but included so all functions have a consistent signature
  @param {Object} [dependentValues] If the function can be calculated from the results of other functions, this allows
    you to provide those pre-calculated values.
  @return {Number} The median
  ###
  functions.median = functions.percentileCreator(50)

  functions.expandFandAs = (a) ->
    ###
    @method expandFandAs
    @static
    @param {Object} a Will look like this `{as: 'mySum', f: 'sum', field: 'Points'}`
    @return {Object} returns the expanded specification

    Takes specifications for functions and expands them to include the actual function and 'as'. If you do not provide
    an 'as' property, it will build it from the field name and function with an underscore between. Also, if the
    'f' provided is a string, it is copied over to the 'metric' property before the 'f' property is replaced with the
    actual function. `{field: 'a', f: 'sum'}` would expand to `{as: 'a_sum', field: 'a', metric: 'sum', f: [Function]}`.
    ###
    utils.assert(a.f?, "'f' missing from specification: \n#{JSON.stringify(a, undefined, 4)}")
    if utils.type(a.f) == 'function'
      throw new Error('User defined metric functions not supported in a stored procedure')
      utils.assert(a.as?, 'Must provide "as" field with your aggregation when providing a user defined function')
      a.metric = a.f.toString()
    else if functions[a.f]?
      a.metric = a.f
      a.f = functions[a.f]
    else if a.f.substr(0, 1) == 'p'
      a.metric = a.f
      p = /\p(\d+(.\d+)?)/.exec(a.f)[1]
      a.f = functions.percentileCreator(Number(p))
    else
      throw new Error("#{a.f} is not a recognized built-in function")

    unless a.as?
      if a.metric == 'count'
        a.field = ''
        a.metric = 'count'
      a.as = "#{a.field}_#{a.metric}"
      utils.assert(a.field? or a.f == 'count', "'field' missing from specification: \n#{JSON.stringify(a, undefined, 4)}")
    return a

  functions.expandMetrics = (metrics = [], addCountIfMissing = false, addValuesForCustomFunctions = false) ->
    ###
    @method expandMetrics
    @static
    @private

    This is called internally by several Lumenize Calculators. You should probably not call it.
    ###
    confirmMetricAbove = (m, fieldName, aboveThisIndex) ->
      if m is 'count'
        lookingFor = '_' + m
      else
        lookingFor = fieldName + '_' + m
      i = 0
      while i < aboveThisIndex
        currentRow = metrics[i]
        if currentRow.as == lookingFor
          return true
        i++
      # OK, it's not above, let's now see if it's below. Then throw error.
      i = aboveThisIndex + 1
      metricsLength = metrics.length
      while i < metricsLength
        currentRow = metrics[i]
        if currentRow.as == lookingFor
          throw new Error("Depdencies must appear before the metric they are dependant upon. #{m} appears after.")
        i++
      return false

    assureDependenciesAbove = (dependencies, fieldName, aboveThisIndex) ->
      for d in dependencies
        unless confirmMetricAbove(d, fieldName, aboveThisIndex)
          if d == 'count'
            newRow = {f: 'count'}
          else
            newRow = {f: d, field: fieldName}
          functions.expandFandAs(newRow)
          metrics.unshift(newRow)
          return false
      return true

    # add values for custom functions
    if addValuesForCustomFunctions
      for m, index in metrics
        if utils.type(m.f) is 'function'
          unless m.f.dependencies?
            m.f.dependencies = []
          unless m.f.dependencies[0] is 'values'
            m.f.dependencies.push('values')
          unless confirmMetricAbove('values', m.field, index)
            valuesRow = {f: 'values', field: m.field}
            functions.expandFandAs(valuesRow)
            metrics.unshift(valuesRow)

    hasCount = false
    for m in metrics
      functions.expandFandAs(m)
      if m.metric is 'count'
        hasCount = true

    if addCountIfMissing and not hasCount
      countRow = {f: 'count'}
      functions.expandFandAs(countRow)
      metrics.unshift(countRow)

    index = 0
    while index < metrics.length  # intentionally not caching length because the loop can add rows
      metricsRow = metrics[index]
      if utils.type(metricsRow.f) is 'function'
        dependencies = ['values']
      if metricsRow.f.dependencies?
        unless assureDependenciesAbove(metricsRow.f.dependencies, metricsRow.field, index)
          index = -1
      index++

    return metrics


# OLAPCube

  # !TODO: Add summary metrics
  # !TODO: Be smart enough to move dependent metrics to the deriveFieldsOnOutput

  class OLAPCube
    ###
    @class OLAPCube

    __An efficient, in-memory, incrementally-updateable, hierarchy-capable OLAP Cube implementation.__

    [OLAP Cubes](http://en.wikipedia.org/wiki/OLAP_cube) are a powerful abstraction that makes it easier to do everything
    from simple group-by operations to more complex multi-dimensional and hierarchical analysis. This implementation has
    the same conceptual ancestry as implementations found in business intelligence and OLAP database solutions. However,
    it is meant as a light weight alternative primarily targeting the goal of making it easier for developers to implement
    desired analysis. It also supports serialization and incremental updating so it's ideally
    suited for visualizations and analysis that are updated on a periodic or even continuous basis.

    ## Features ##

    * In-memory
    * Incrementally-updateable
    * Serialize (`getStateForSaving()`) and deserialize (`newFromSavedState()`) to preserve aggregations between sessions
    * Accepts simple JavaScript Objects as facts
    * Storage and output as simple JavaScript Arrays of Objects
    * Hierarchy (trees) derived from fact data assuming [materialized path](http://en.wikipedia.org/wiki/Materialized_path)
      array model commonly used with NoSQL databases

    ## 2D Example ##

    Let's walk through a simple 2D example from facts to output. Let's say you have this set of facts:

        facts = [
          {ProjectHierarchy: [1, 2, 3], Priority: 1, Points: 10},
          {ProjectHierarchy: [1, 2, 4], Priority: 2, Points: 5 },
          {ProjectHierarchy: [5]      , Priority: 1, Points: 17},
          {ProjectHierarchy: [1, 2]   , Priority: 1, Points: 3 },
        ]

    The ProjectHierarchy field models its hierarchy (tree) as an array containing a
    [materialized path](http://en.wikipedia.org/wiki/Materialized_path). The first fact is "in" Project 3 whose parent is
    Project 2, whose parent is Project 1. The second fact is "in" Project 4 whose parent is Project 2 which still has
    Project 1 as its parent. Project 5 is another root Project like Project 1; and the fourth fact is "in" Project 2.
    So the first fact will roll-up the tree and be aggregated against [1], and [1, 2] as well as [1, 2, 3]. Root Project 1
    will get the data from all but the third fact which will get aggregated against root Project 5.

    We specify the ProjectHierarchy field as a dimension of type 'hierarchy' and the Priorty field as a simple value dimension.

        dimensions = [
          {field: "ProjectHierarchy", type: 'hierarchy'},
          {field: "Priority"}
        ]

    This will create a 2D "cube" where each unique value for ProjectHierarchy and Priority defines a different cell.
    Note, this happens to be a 2D "cube" (more commonly referred to as a [pivot table](http://en.wikipedia.org/wiki/Pivot_Table)),
    but you can also have a 1D cube (a simple group-by), a 3D cube, or even an n-dimensional hypercube where n is greater than 3.

    You can specify any number of metrics to be calculated for each cell in the cube.

        metrics = [
          {field: "Points", f: "sum", as: "Scope"}
        ]

    You can use any of the aggregation functions found in Lumenize.functions except `count`. The count metric is
    automatically tracked for each cell. The `as` specification is optional unless you provide a custom function. If missing,
    it will build the name of the resulting metric from the field name and the function. So without the `as: "Scope"` the
    second metric in the example above would have been named "Points_sum".

    You can also use custom functions in the form of `f(values) -> return <some function of values>`.

    Next, we build the config parameter from our dimension and metrics specifications.

        config = {dimensions, metrics}

    Hierarchy dimensions automatically roll up but you can also tell it to keep all totals by setting config.keepTotals to
    true. The totals are then kept in the cells where one or more of the dimension values are set to `null`. Note, you
    can also set keepTotals for individual dimension and should probably use that if you have more than a few dimensions
    but we're going to set it globally here:

        config.keepTotals = true

    Now, let's create the cube.

        {OLAPCube} = require('../')
        cube = new OLAPCube(config, facts)

    `getCell()` allows you to extract a single cell. The "total" cell for all facts where Priority = 1 can be found as follows:

        console.log(cube.getCell({Priority: 1}))
        # { ProjectHierarchy: null, Priority: 1, _count: 3, Scope: 30 }

    Notice how the ProjectHierarchy field value is `null`. This is because it is a total cell for Priority dimension
    for all ProjectHierarchy values. Think of `null` values in this context as wildcards.

    Similarly, we can get the total for all descendants of ProjectHierarchy = [1] regarless of Priority as follows:

        console.log(cube.getCell({ProjectHierarchy: [1]}))
        # { ProjectHierarchy: [ 1 ], Priority: null, _count: 3, Scope: 18 }

    `getCell()` uses the cellIndex so it's very efficient. Using `getCell()` and `getDimensionValues()`, you can iterate
    over a slice of the OLAPCube. It is usually preferable to access the cells in place like this rather than the
    traditional OLAP approach of extracting a slice for processing. However, there is a `slice()` method for extracting
    a 2D slice.

        rowValues = cube.getDimensionValues('ProjectHierarchy')
        columnValues = cube.getDimensionValues('Priority')
        s = OLAPCube._padToWidth('', 7) + ' | '
        s += ((OLAPCube._padToWidth(JSON.stringify(c), 7) for c in columnValues).join(' | '))
        s += ' | '
        console.log(s)
        for r in rowValues
          s = OLAPCube._padToWidth(JSON.stringify(r), 7) + ' | '
          for c in columnValues
            cell = cube.getCell({ProjectHierarchy: r, Priority: c})
            if cell?
              cellString = JSON.stringify(cell._count)
            else
              cellString = ''
            s += OLAPCube._padToWidth(cellString, 7) + ' | '
          console.log(s)
        #         |    null |       1 |       2 |
        #    null |       4 |       3 |       1 |
        #     [1] |       3 |       2 |       1 |
        #   [1,2] |       3 |       2 |       1 |
        # [1,2,3] |       1 |       1 |         |
        # [1,2,4] |       1 |         |       1 |
        #     [5] |       1 |       1 |         |

    Or you can just call `toString()` method which extracts a 2D slice for tabular display. Both approachs will work on
    cubes of any number of dimensions two or greater. The manual example above extracted the `count` metric. We'll tell
    the example below to extract the `Scope` metric.

        console.log(cube.toString('ProjectHierarchy', 'Priority', 'Scope'))
        # |        || Total |     1     2|
        # |==============================|
        # |Total   ||    35 |    30     5|
        # |------------------------------|
        # |[1]     ||    18 |    13     5|
        # |[1,2]   ||    18 |    13     5|
        # |[1,2,3] ||    10 |    10      |
        # |[1,2,4] ||     5 |           5|
        # |[5]     ||    17 |    17      |

    ## Dimension types ##

    The following dimension types are supported:

    1. Single value
       * Number
       * String
       * Does not work:
         * Boolean - known to fail
         * Object - may sorta work but sort-order at least is not obvious
         * Date - not tested but may actually work
    2. Arrays as materialized path for hierarchical (tree) data
    3. Non-hierarchical Arrays ("tags")

    There is no need to tell the OLAPCube what type to use with the exception of #2. In that case, add `type: 'hierarchy'`
    to the dimensions row like this:

        dimensions = [
          {field: 'hierarchicalDimensionField', type: 'hierarchy'} #, ...
        ]

    ## Hierarchical (tree) data ##

    This OLAP Cube implementation assumes your hierarchies (trees) are modeled as a
    [materialized path](http://en.wikipedia.org/wiki/Materialized_path) array. This approach is commonly used with NoSQL databases like
    [CouchDB](http://probablyprogramming.com/2008/07/04/storing-hierarchical-data-in-couchdb) and
    [MongoDB (combining materialized path and array of ancestors)](http://docs.mongodb.org/manual/tutorial/model-tree-structures/)
    and even SQL databases supporting array types like [Postgres](http://justcramer.com/2012/04/08/using-arrays-as-materialized-paths-in-postgres/).

    This approach differs from the traditional OLAP/MDX fixed/named level hierarchy approach. In that approach, you assume
    that the number of levels in the hierarchy are fixed. Also, each level in the hierarchy is either represented by a different
    column (clothing example --> level 0: SEX column - mens vs womens; level 1: TYPE column - pants vs shorts vs shirts; etc.) or
    predetermined ranges of values in a single field (date example --> level 0: year; level 1: quarter; level 2: month; etc.)

    However, the approach used by this OLAPCube implementaion is the more general case, because it can easily simulate
    fixed/named level hierachies whereas the reverse is not true. In the clothing example above, you would simply key
    your dimension off of a derived field that was a combination of the SEX and TYPE columns (e.g. ['mens', 'pants'])

    ## Date/Time hierarchies ##

    Lumenize is designed to work well with the tzTime library. Here is an example of taking a bunch of ISOString data
    and doing timezone precise hierarchical roll up based upon the date segments (year, month).

        data = [
          {date: '2011-12-31T12:34:56.789Z', value: 10},
          {date: '2012-01-05T12:34:56.789Z', value: 20},
          {date: '2012-01-15T12:34:56.789Z', value: 30},
          {date: '2012-02-01T00:00:01.000Z', value: 40},
          {date: '2012-02-15T12:34:56.789Z', value: 50},
        ]

        {Time} = require('../')

        config =
          deriveFieldsOnInput: [{
            field: 'dateSegments',
            f: (row) ->
              return new Time(row.date, Time.MONTH, 'America/New_York').getSegmentsAsArray()
          }]
          metrics: [{field: 'value', f: 'sum'}]
          dimensions: [{field: 'dateSegments', type: 'hierarchy'}]

        cube = new OLAPCube(config, data)
        console.log(cube.toString(undefined, undefined, 'value_sum'))
        # | dateSegments | value_sum |
        # |==========================|
        # | [2011]       |        10 |
        # | [2011,12]    |        10 |
        # | [2012]       |       140 |
        # | [2012,1]     |        90 |
        # | [2012,2]     |        50 |

    Notice how '2012-02-01T00:00:01.000Z' got bucketed in January because the calculation was done in timezone
    'America/New_York'.

    ## Non-hierarchical Array fields ##

    If you don't specify type: 'hierarchy' and the OLAPCube sees a field whose value is an Array in a dimension field, the
    data in that fact would get aggregated against each element in the Array. So a non-hierarchical Array field like
    ['x', 'y', 'z'] would get aggregated against 'x', 'y', and 'z' rather than ['x'], ['x', 'y'], and ['x','y','z]. This
    functionality is useful for  accomplishing analytics on tags, but it can be used in other powerful ways. For instance
    let's say you have a list of events:

        events = [
          {name: 'Renaissance Festival', activeMonths: ['September', 'October']},
          {name: 'Concert Series', activeMonths: ['July', 'August', 'September']},
          {name: 'Fall Festival', activeMonths: ['September']}
        ]

    You could figure out the number of events active in each month by specifying "activeMonths" as a dimension.
    Lumenize.TimeInStateCalculator (and other calculators in Lumenize) use this technique.
    ###

    constructor: (@userConfig, facts) ->
      ###
      @constructor
      @param {Object} config See Config options for details. DO NOT change the config settings after the OLAP class is instantiated.
      @param {Object[]} [facts] Optional parameter allowing the population of the OLAPCube with an intitial set of facts
        upon instantiation. Use addFacts() to add facts after instantiation.
      @cfg {Object[]} [dimensions] Array which specifies the fields to use as dimension fields. If the field contains a
        hierarchy array, say so in the row, (e.g. `{field: 'SomeFieldName', type: 'hierarchy'}`). Any array values that it
        finds in the supplied facts will be assumed to be tags rather than a hierarchy specification unless `type: 'hierarchy'`
        is specified.

        For example, let's say you have a set of facts that look like this:

          fact = {
            dimensionField: 'a',
            hierarchicalDimensionField: ['1','2','3'],
            tagDimensionField: ['x', 'y', 'z'],
            valueField: 10
          }

        Then a set of dimensions like this makes sense.

          config.dimensions = [
            {field: 'dimensionField'},
            {field: 'hierarchicalDimensionField', type: 'hierarchy'},
            {field: 'tagDimensionField', keepTotals: true}
          ]

        Notice how a keepTotals can be set for an individual dimension. This is preferable to setting it for the entire
        cube in cases where you don't want totals in all dimensions.

        If no dimension config is provided, then you must use syntactic sugar like groupBy.

      @cfg {String} [groupBy] Syntactic sugar for single-dimension/single-metric usage.
      @cfg {String} [f] Syntactic sugar for single-dimension/single-metric usage. If provided, you must also provide
        a `groupBy` config. If you provided a `groupBy` but no `f` or `field`, then the default `count` metric will be used.
      @cfg {String} [field] Syntactic sugar for single-dimension/single-metric usage. If provided, you must also provide
        a `groupBy` config. If you provided a `groupBy` but no `f` or `field`, then the default `count` metric will be used.

      @cfg {Object[]} [metrics=[]] Array which specifies the metrics to calculate for each cell in the cube.

        Example:

          config = {}
          config.metrics = [
            {field: 'field3'},                                      # defaults to metrics: ['sum']
            {field: 'field4', metrics: [
              {f: 'sum'},                                           # will add a metric named field4_sum
              {as: 'median4', f: 'p50'},                            # renamed p50 to median4 from default of field4_p50
              {as: 'myCount', f: (values) -> return values.length}  # user-supplied function
            ]}
          ]

        If you specify a field without any metrics, it will assume you want the sum but it will not automatically
        add the sum metric to fields with a metrics specification. User-supplied aggregation functions are also supported as
        shown in the 'myCount' metric above.

        Note, if the metric has dependencies (e.g. average depends upon count and sum) it will automatically add those to
        your metric definition. If you've already added a dependency but put it under a different "as", it's not smart
        enough to sense that and it will add it again. Either live with the slight inefficiency and duplication or leave
        dependency metrics named their default by not providing an "as" field.

      @cfg {Boolean} [keepTotals=false] Setting this will add an additional total row (indicated with field: null) along
        all dimensions. This setting can have an impact on the memory usage and performance of the OLAPCube so
        if things are tight, only use it if you really need it. If you don't need it for all dimension, you can specify
        keepTotals for individual dimensions.
      @cfg {Boolean} [keepFacts=false] Setting this will cause the OLAPCube to keep track of the facts that contributed to
        the metrics for each cell by adding an automatic 'facts' metric. Note, facts are restored after deserialization
        as you would expect, but they are no longer tied to the original facts. This feature, especially after a restore
        can eat up memory.
      @cfg {Object[]} [deriveFieldsOnInput] An Array of Maps in the form `{field:'myField', f:(fact)->...}`
      @cfg {Object[]} [deriveFieldsOnOutput] same format as deriveFieldsOnInput, except the callback is in the form `f(row)`
        This is only called for dirty rows that were effected by the latest round of addFacts. It's more efficient to calculate things
        like standard deviation and percentile coverage here than in config.metrics. You just have to remember to include the dependencies
        in config.metrics. Standard deviation depends upon `sum` and `sumSquares`. Percentile coverage depends upon `values`.
        In fact, if you are going to capture values anyway, all of the functions are most efficiently calculated here.
        Maybe some day, I'll write the code to analyze your metrics and move them out to here if it improves efficiency.
      ###
      @config = utils.clone(@userConfig)
      @cells = []
      @cellIndex = {}
      @currentValues = {}

      # Syntactic sugar for groupBy
      if @config.groupBy?
        @config.dimensions = [{field: @config.groupBy}]
        if @config.f? and @config.field?
          @config.metrics = [{field: @config.field, f: @config.f}]

      utils.assert(@config.dimensions?, 'Must provide config.dimensions.')
      unless @config.metrics?
        @config.metrics = []

      @_dimensionValues = {}  # key: fieldName, value: {} where key: uniqueValue, value: the real key (not stringified)
      for d in @config.dimensions
        @_dimensionValues[d.field] = {}

      unless @config.keepTotals
        @config.keepTotals = false
      unless @config.keepFacts
        @config.keepFacts = false

      for d in @config.dimensions
        if @config.keepTotals or d.keepTotals
          d.keepTotals = true
        else
          d.keepTotals = false

      functions.expandMetrics(@config.metrics, true, true)

      # Set required fields
      requiredFieldsObject = {}
      for m in @config.metrics
        if m.field?.length > 0  # Should only be false if function is count
          requiredFieldsObject[m.field] = null
      for d in @config.dimensions
        requiredFieldsObject[d.field] = null
      @requiredFields = (key for key, value of requiredFieldsObject)

      @summaryMetrics = {}

      @addFacts(facts)

    @_possibilities: (key, type, keepTotals) ->
      switch utils.type(key)
        when 'array'
          if keepTotals
            a = [null]
          else
            a = []
          if type == 'hierarchy'
            len = key.length
            while len > 0
              a.push(key.slice(0, len))
              len--
          else  # assume it's a tag array
            if keepTotals
              a = [null].concat(key)
            else
              a = key
          return a
        when 'string', 'number'
          if keepTotals
            return [null, key]
          else
            return [key]


    @_decrement: (a, rollover) ->
      i = a.length - 1
      a[i]--
      while a[i] < 0
        a[i] = rollover[i]
        i--
        if i < 0
          return false
        else
          a[i]--
      return true

    _expandFact: (fact) ->
      possibilitiesArray = []
      countdownArray = []
      rolloverArray = []
      for d in @config.dimensions
        p = OLAPCube._possibilities(fact[d.field], d.type, d.keepTotals)
        possibilitiesArray.push(p)
        countdownArray.push(p.length - 1)
        rolloverArray.push(p.length - 1)  # !TODO: If I need some speed, we could calculate the rolloverArray once and make a copy to the countdownArray for each run

      for m in @config.metrics
        @currentValues[m.field] = [fact[m.field]]  # !TODO: Add default values here. I think this is the only place it is needed. write tests with incremental update to confirm.
      out = []
      more = true
      while more
        outRow = {}
        for d, index in @config.dimensions
          outRow[d.field] = possibilitiesArray[index][countdownArray[index]]
        outRow._count = 1
        if @config.keepFacts
          outRow._facts = [fact]
        for m in @config.metrics
          outRow[m.as] = m.f([fact[m.field]], undefined, undefined, outRow, m.field + '_')
        out.push(outRow)
        more = OLAPCube._decrement(countdownArray, rolloverArray)

      return out

    @_extractFilter: (row, dimensions) ->
      out = {}
      for d in dimensions
        out[d.field] = row[d.field]
      return out

    _mergeExpandedFactArray: (expandedFactArray) ->
      for er in expandedFactArray
        # set _dimensionValues
        for d in @config.dimensions
          fieldValue = er[d.field]
          @_dimensionValues[d.field][JSON.stringify(fieldValue)] = fieldValue

        # start merge
        filterString = JSON.stringify(OLAPCube._extractFilter(er, @config.dimensions))
        olapRow = @cellIndex[filterString]
        if olapRow?
          for m in @config.metrics
            olapRow[m.as] = m.f(olapRow[m.field + '_values'], olapRow[m.as], @currentValues[m.field], olapRow, m.field + '_')
        else
          olapRow = er
          @cellIndex[filterString] = olapRow
          @cells.push(olapRow)
        @dirtyRows[filterString] = olapRow

    addFacts: (facts) ->
      ###
      @method addFacts
        Adds facts to the OLAPCube.

      @chainable
      @param {Object[]} facts An Array of facts to be aggregated into OLAPCube. Each fact is a Map where the keys are the field names
        and the values are the field values (e.g. `{field1: 'a', field2: 5}`).
      ###
      @dirtyRows = {}

      if utils.type(facts) == 'array'
        if facts.length <= 0
          return
      else
        if facts?
          facts = [facts]
        else
          return

      if @config.deriveFieldsOnInput
        for fact in facts
          for d in @config.deriveFieldsOnInput
            if d.as?
              fieldName = d.as
            else
              fieldName = d.field
            fact[fieldName] = d.f(fact)

      for fact in facts
        missingFields = @calculateMissingFields(fact)
        if missingFields.length is 0
          @currentValues = {}
          expandedFactArray = @_expandFact(fact)
          @_mergeExpandedFactArray(expandedFactArray)
        else
          unless memo.warnings?
            memo.warnings = []
          memo.warnings.push({type: 'Missing fields', missingFields, fact})

      # deriveFieldsOnOutput for @dirtyRows
      if @config.deriveFieldsOnOutput?
        for filterString, dirtyRow of @dirtyRows
          for d in @config.deriveFieldsOnOutput
            if d.as?
              fieldName = d.as
            else
              fieldName = d.field
            dirtyRow[fieldName] = d.f(dirtyRow)
      @dirtyRows = {}

      return this

    calculateMissingFields: (fact) ->
      missingFields = []
      for field in @requiredFields
        unless fact[field]?
          missingFields.push(field)
      return missingFields

    getCells: (filterObject) ->
      ###
      @method getCells
        Returns a subset of the cells that match the supplied filter. You can perform slice and dice operations using
        this. If you have criteria for all of the dimensions, you are better off using `getCell()`. Most times, it's
        better to iterate over the unique values for the dimensions of interest using `getCell()` in place of slice or
        dice operations. However, there is a `slice()` method for extracting a 2D slice
      @param {Object} [filterObject] Specifies the constraints that the returned cells must match in the form of
        `{field1: value1, field2: value2}`. If this parameter is missing, the internal cells array is returned.
      @return {Object[]} Returns the cells that match the supplied filter
      ###
      unless filterObject?
        return @cells

      output = []
      for c in @cells
        if utils.filterMatch(filterObject, c)
          output.push(c)
      return output

    getCell: (filter, defaultValue) ->
      ###
      @method getCell
        Returns the single cell matching the supplied filter. Iterating over the unique values for the dimensions of
        interest, you can incrementally retrieve a slice or dice using this method. Since `getCell()` always uses an index,
        in most cases, this is better than using `getCells()` to prefetch a slice or dice.
      @param {Object} [filter={}] Specifies the constraints for the returned cell in the form of `{field1: value1, field2: value2}.
        Any fields that are specified in config.dimensions that are missing from the filter are automatically filled in
        with null. Calling `getCell()` with no parameter or `{}` will return the total of all dimensions (if @config.keepTotals=true).
      @return {Object[]} Returns the cell that match the supplied filter
      ###
      unless filter?
        filter = {}

      for key, value of filter
        foundIt = false
        for d in @config.dimensions
          if d.field == key
            foundIt = true
        unless foundIt
          throw new Error("#{key} is not a dimension for this cube.")

      normalizedFilter = {}
      for d in @config.dimensions
        if filter.hasOwnProperty(d.field)
          normalizedFilter[d.field] = filter[d.field]
        else
          if d.keepTotals
            normalizedFilter[d.field] = null
          else
            throw new Error('Must set keepTotals to use getCell with a partial filter.')
      cell = @cellIndex[JSON.stringify(normalizedFilter)]
      if cell?
        return cell
      else
        return defaultValue

    getDimensionValues: (field, descending = false) ->
      ###
      @method getDimensionValues
        Returns the unique values for the specified dimension in sort order.
      @param {String} field The field whose values you want
      @param {Boolean} [descending=false] Set to true if you want them in reverse order
      ###
      values = utils.values(@_dimensionValues[field])
      values.sort(utils.compare)
      unless descending
        values.reverse()
      return values

    @roundToSignificance: (value, significance) ->
      unless significance?
        return value
      multiple = 1 / significance
      return Math.floor(value * multiple) / multiple

    slice: (rows, columns, metric, significance) ->
      ###
      @method slice
        Extracts a 2D slice of the data. It outputs an array of arrays (JavaScript two-dimensional array) organized as the
        C3 charting library would expect if submitting row-oriented data. Note, the output of this function is very similar
        to the 2D toString() function output except the data is organized as a two-dimensional array instead of newline-separated
        lines and the cells are filled with actual values instead of padded string representations of those values.
      @return {[[]]} An array of arrays with the one row for the header and each row label
      @param {String} [rows=<first dimension>]
      @param {String} [columns=<second dimension>]
      @param {String} [metric='count']
      @param {Number} [significance] The multiple to which you want to round the bucket edges. 1 means whole numbers.
        0.1 means to round to tenths. 0.01 to hundreds. Etc.
      ###
      unless rows?
        rows = @config.dimensions[0].field
      unless columns?
        columns = @config.dimensions[1].field
      rowValues = @getDimensionValues(rows)
      columnValues = @getDimensionValues(columns)
      values = []
      topRow = []
      topRow.push('x')
      for c, indexColumn in columnValues
        if c is null
          topRow.push('Total')
        else
          topRow.push(c)
      values.push(topRow)
      for r, indexRow in rowValues
        valuesRow = []
        if r is null
          valuesRow.push('Total')
        else
          valuesRow.push(r)
        for c, indexColumn in columnValues
          filter = {}
          filter[rows] = r
          filter[columns] = c
          cell = @getCell(filter)
          if cell?
            cellValue = OLAPCube.roundToSignificance(cell[metric], significance)
          else
            cellValue = null
          valuesRow.push(cellValue)
        values.push(valuesRow)

      return values

    @_padToWidth: (s, width, padCharacter = ' ', rightPad = false) ->
      if s.length > width
        return s.substr(0, width)
      padding = new Array(width - s.length + 1).join(padCharacter)
      if rightPad
        return s + padding
      else
        return padding + s

    getStateForSaving: (meta) ->
      ###
      @method getStateForSaving
        Enables saving the state of an OLAPCube.
      @param {Object} [meta] An optional parameter that will be added to the serialized output and added to the meta field
        within the deserialized OLAPCube
      @return {Object} Returns an Ojbect representing the state of the OLAPCube. This Object is suitable for saving to
        to an object store. Use the static method `newFromSavedState()` with this Object as the parameter to reconstitute the OLAPCube.

          facts = [
            {ProjectHierarchy: [1, 2, 3], Priority: 1},
            {ProjectHierarchy: [1, 2, 4], Priority: 2},
            {ProjectHierarchy: [5]      , Priority: 1},
            {ProjectHierarchy: [1, 2]   , Priority: 1},
          ]

          dimensions = [
            {field: "ProjectHierarchy", type: 'hierarchy'},
            {field: "Priority"}
          ]

          config = {dimensions, metrics: []}
          config.keepTotals = true

          originalCube = new OLAPCube(config, facts)

          dateString = '2012-12-27T12:34:56.789Z'
          savedState = originalCube.getStateForSaving({upToDate: dateString})
          restoredCube = OLAPCube.newFromSavedState(savedState)

          newFacts = [
            {ProjectHierarchy: [5], Priority: 3},
            {ProjectHierarchy: [1, 2, 4], Priority: 1}
          ]
          originalCube.addFacts(newFacts)
          restoredCube.addFacts(newFacts)

          console.log(restoredCube.toString() == originalCube.toString())
          # true

          console.log(restoredCube.meta.upToDate)
          # 2012-12-27T12:34:56.789Z
      ###
      out =
        config: @userConfig
        cellsAsCSVStyleArray: arrayOfMaps_To_CSVStyleArray(@cells)  # !TODO: This makes the package smaller, but it's less well tested than using the Maps like the line below.
#        cells: @cells
        summaryMetrics: @summaryMetrics
      if meta?
        out.meta = meta
      return out

    @newFromSavedState: (p) ->
      ###
      @method newFromSavedState
        Deserializes a previously stringified OLAPCube and returns a new OLAPCube.

        See `getStateForSaving()` documentation for a detailed example.

        Note, if you have specified config.keepFacts = true, the values for the facts will be restored, however, they
        will no longer be references to the original facts. For this reason, it's usually better to include a `values` or
        `uniqueValues` metric on some ID field if you want fact drill-down support to survive a save and restore.
      @static
      @param {String/Object} p A String or Object from a previously saved OLAPCube state
      @return {OLAPCube}
      ###
      if utils.type(p) is 'string'
        p = JSON.parse(p)
      cube = new OLAPCube(p.config)
      cube.summaryMetrics = p.summaryMetrics
      if p.meta?
        cube.meta = p.meta
      if p.cellsAsCSVStyleArray?
        cube.cells = csvStyleArray_To_ArrayOfMaps(p.cellsAsCSVStyleArray)
      else
        cube.cells = p.cells
      cube.cellIndex = {}
      cube._dimensionValues = {}
      for d in cube.config.dimensions
        cube._dimensionValues[d.field] = {}
      for c in cube.cells
        filterString = JSON.stringify(OLAPCube._extractFilter(c, cube.config.dimensions))
        # rebuild cellIndex
        cube.cellIndex[filterString] = c
        # rebuild _dimensionValues
        for d in cube.config.dimensions
          fieldValue = c[d.field]
          cube._dimensionValues[d.field][JSON.stringify(fieldValue)] = fieldValue

      return cube


# cube

  # !TODO: Need some way to tell if I'm getting close to the memory constraints?
  context = getContext()
  collection = context.getCollection()

  unless memo.continuation?
    memo.continuation = null

  if memo.savedCube?
    theCube = OLAPCube.newFromSavedState(memo.savedCube)
  else if memo.cubeConfig?
    theCube = new OLAPCube(memo.cubeConfig)
  else
    throw new Error('cubeConfig or savedCube required')

  memo.stillQueueing = true

  query = () ->
    setBody()
    if memo.stillQueueing
      responseOptions =
        continuation: memo.continuation
        pageSize: 1000

      if memo.filterQuery?
        memo.stillQueueing = collection.queryDocuments(collection.getSelfLink(), memo.filterQuery, responseOptions, onReadDocuments)
      else
        memo.stillQueueing = collection.readDocuments(collection.getSelfLink(), responseOptions, onReadDocuments)

  onReadDocuments = (err, resources, options) ->
    if err?
      throw new Error(JSON.stringify(err))

    theCube.addFacts(resources)
    memo.savedCube = theCube.getStateForSaving()
    memo.example = resources[0]
    if options.continuation?
      memo.continuation = options.continuation
      query()
    else
      memo.continuation = null
      setBody()

  setBody = () ->
    getContext().getResponse().setBody(memo)

  query()
  return memo

exports.cube = cube