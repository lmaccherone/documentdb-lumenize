# documentdb-lumenize #

Copyright (c) 2015, Lawrence S. Maccherone, Jr.

_Aggregations (Group-by, Pivot-table, and N-dimensional Cube) and Time Series Transformations as Stored Procedures in DocumentDB_

**The bad news**: DocumentDB does not include aggregation capability.

**The good news**: DocumentDB includes stored procedures and documentdb-lumenize uses this to add aggregation capability that far exceeds that which you are used to with SQL.


## Source code ##

* [Source Repository](https://github.com/lmaccherone/documentdb-lumenize)


## Features ##

  
### Working ###

* Fast, light, flexible OLAP Cube with hierarchical rollup support running inside your DocumentDB collections for super-fast results.
* Syntactic sugar for single-metric/single-dimension group by.

### Wish list ###

* Automatically send back an additional output with just an array for the one metric specified by a simple groupBy.
* Syntactic sugar for single-metric pivot table. Note, a pivot table is just a two-dimensional cube, so you can do them now. It just might be nice to have a convenient way for simple aggregations.
* Allow for parameterization of filterQuery
* deriveFieldsOnOutput/Input functionality using string function names.
* A way to specify a slice, min, max, etc. as the output. This would be especially useful for folks who are not using node.js where they can simply reload the savedCube locally to get that functionality.
* Maybe a C# version of the client-side functionality that I now have by using the full Lumenize.OLAPCube.
* Turn DocumentDB into a powerful time-series database and analysis engine. The Lumenize calculators do their thing by calling the Lumenize OLAPCube so it should be easy to get them to run on top of the stored procedure version of the OLAP Cube.
  * TimeSeriesCalculator - Show how aggregations changed over time. Visualize cumulative flow.
  * TimeInStateCalculator - See how long your entities spend in certain states. Calculate the ratio of wait to touch time. Find 98 percentile of lead time to set service level agreements.
  * TransitionsCalculator - Know the frequency of particular state transition and aggregstions of those transitions. How much work of type X was finished in each of the last 12 months? Throughput. Velocity.

## Install ##

`npm install -save documentdb-lumenize`

or

`bower install -save documentdb-lumenize`

Note, the bower alternative only installs the stored-procedures in `.string` form.


## Usage ##

### Pushing the stored procedure(s) into DocumentDB and executing it ###

There are several ways to get the stored procedure(s) into your DocumentationDB collection and execute it. 

* When using node.js, the easiest is to use documentdb-utils, but there are two ways to even do that:

  * `require` the stored procedure and pass it in to documentdb-utils with the `storedProcedureJS` config field.
  
          documentDBUtils = require('documentdb-utils')
          {OLAPCube} = require('lumenize')
    
          {cube} = require('./stored-procedures/cube')
          
          cubeConfig = <your aggregation configuration (see below)>
    
          config =
            databaseID: 'test-stored-procedure'
            collectionID: 'testing-s3'
            storedProcedureID: 'cube'
            storedProcedureJS: cube
            memo: {cubeConfig}
            debug: false
    
          processResponse = (err, response) ->
            if err?
              throw new Error(JSON.stringify(err))
            console.log(response.stats)
            cube = OLAPCube.newFromSavedState(response.memo.savedCube)
            console.log(cube.toString())
    
          documentDBUtils(config, processResponse)
          
  * There is a stringified version of the cube code under `stored-procedures/cube.string`. You can load this file into a String using `fs.readFileSync()` and send this string in to documentdb-utils with the `storedProcedureJS` config field.
  
    This would basically look the same as the first example, but replace this line:
    
        {cube} = require('./stored-procedures/cube')
        
    With this line:
    
        cube = require('fs').readFileSync('./stored-procedures/cube.string', 'utf8')
  
* If you are using .NET or the REST API from some other platform, then you can load the stringified version using the file read capabilities of that platform and send it using your .NET or REST API. Note, that if the stored procedure hits the timeout before it's done
going through all of the data specified by your filterQuery, it will return with partially aggregated results and a continuation token. Merely pass back in (after any specified `x-ms-retry-after-ms`) the memo object that came back in the response body as the parameter to the next call of the stored procedure. It will take care of continuing right where it left off. When using documentdb-utils, this delay and retry logic is automatically taken care of for you among other niceties.

### A simple group by example ###

Let's assume this is the only data in your collection.

    [
      {id: 1, value: 10}
      {id: 1, value: 100}
      {id: 2, value: 20}
      {id: 3, value: 30}
    ]

Now, let's call the cube with the following:
    
    {cubeConfig: {groupBy: 'id', field: "value", f: "sum"}}
  
After you call the cube stored procedure, you should expect this to be in the `savedCube.cellsAsCSVStyleArray` parameter of the response. Note, the _count metric is always
calculated even when not specified.

    [
      [ 'id', '_count', 'value_sum' ],
      [   1,         2,         110 ],
      [   2,         1,          20 ],
      [   3,         1,          30 ]
    ]

### Available aggregation functions ###

All of the [Lumenize aggregation functions](http://commondatastorage.googleapis.com/versions.lumenize.com/docs/lumenize-docs/index.html#!/api/Lumenize.functions) are supported including but not limited to:

* `sum`
* `count`
* `average`
* `max`
* `min`
* `median`
* `standardDeviation`
* `variance`
* `product` (careful, this can overflow fast)
* `sumSquares`
* `sumCubes`
* `values`
* `uniqueValues`
* and, any percentile by simply using using the string `p<your-percentile>` (e.g. `p75`, which is the upper quartile)

Please note that when using any metric that cannot be incrementally calculated (median and percentiles in the list above), for large aggregations, it's more efficient to use the cube with a `values` metric and calculate your median or percentile after the fact. You can call `Lumenize.functions.median(values)` for each cell in the cube that returned. The deriveFieldsOnOutput functionality of the full Lumenize.OLAPCube is not supported yet in this stored-procedure form.

### Providing a filterQuery ###

Now, let's assume the same set of facts in the collection, but we add a `filterQuery`

    cubeConfig = {groupBy: 'id', field: "value", f: "sum"}
    filterQuery = 'SELECT * FROM Facts f WHERE f.id = 1'

And we call the cube stored procedure with

    {cubeConfig: cubeConfig, filterQuery: filterQuery}

You should expect to see this in the `savedCube.cellsAsCSVStyleArray` parameter that is returned.

    [
      [ 'id', '_count', 'value_sum' ],
      [    1,        2,         110 ]
    ]
    
It's possible to pass in an Object containing both a parameterized string for the filterQuery and the parameters as specified [here](http://dl.windowsazure.com/documentDB/nodedocs/global.html#SqlQuerySpec). Note, when you compose your `filterQuery` you must make sure that all the expected fields are returned.

### A hierarchical pivot table (2D OLAPCube) example ###

Let's walk through a simple 2D example from facts to output. Let's say you have this set of facts in your collection or returned with your `filterQuery`:

    [
      {ProjectHierarchy: [1, 2, 3], Priority: 1, Points: 10},
      {ProjectHierarchy: [1, 2, 4], Priority: 2, Points: 5 },
      {ProjectHierarchy: [5]      , Priority: 1, Points: 17},
      {ProjectHierarchy: [1, 2]   , Priority: 1, Points: 3 },
    ]

The ProjectHierarchy field models its hierarchy (tree) as an array containing a
materialized path. The first fact is "in" Project 3 whose parent is Project 2, whose parent is Project 1. The second fact is "in" Project 4 whose parent is Project 2 which still has Project 1 as its parent. Project 5 is another root Project like Project 1; and the fourth fact is "in" Project 2.

So the first fact will roll-up the tree and be aggregated against [1], and [1, 2] as well as [1, 2, 3]. Root Project 1 will get the data from all but the third fact which will get aggregated against root Project 5.

We specify the ProjectHierarchy field as a dimension of type 'hierarchy' and the Priorty field as a normal dimension.

    dimensions = [
      {field: "ProjectHierarchy", type: 'hierarchy'},
      {field: "Priority"}
    ]

This will create a 2D "cube" where each unique value for ProjectHierarchy and Priority defines a different cell. Note, this happens to be a 2D "cube" (more commonly referred to as a [pivot table](http://en.wikipedia.org/wiki/Pivot_Table)), but you can also have a 1D cube (a simple group-by), a 3D cube, or even an n-dimensional hypercube where n is greater than 3.

You can specify any number of metrics to be calculated for each cell in the cube.

    metrics = [
      {field: "Points", f: "sum", as: "Scope"}
    ]

You can use any of the aggregation functions found in Lumenize.functions. Whether you specify it or not, the count metric is automatically tracked for each cell. The `as` specification is optional. If missing, it will build the name of the resulting metric from the field name and the function name. So without the `as: "Scope"` the second metric in the example above would have been named `Points_sum`.

Next, we build the config parameter from our dimension and metrics specifications.

    cubeConfig = {dimensions: dimensions, metrics: metrics}

Hierarchy dimensions automatically roll up but you can also tell it to keep all totals by setting config.keepTotals to true. The totals are then kept in the cells where one or more of the dimension values are set to `null`. Note, you can also set keepTotals for individual dimension and should probably use that if you have more than a few dimensions
but we're going to set it globally here:

    cubeConfig.keepTotals = true

Now, let's call our cube stored procedure with the following:

    {cubeConfig: cubeConfig}
    
We can inspect `savedCube.cellsAsCSVStyleArray` like we did in the simple groupBy examples above, but let's use the full power of Lumenize's OLAP cube to get the output of the results
this time. You can rehydrate the cube in the browser or node.js by passing in the value returned as `savedCube` into Lumenize's `OLAPCube.newFromSavedState`.

    OLAPCube = require('lumenize').OLAPCube
    cube = OLAPCube.newFromSavedState(savedCube)

You can check out the [full documentation for the Lumenize OLAPCube](http://commondatastorage.googleapis.com/versions.lumenize.com/docs/lumenize-docs/index.html#!/api/Lumenize.OLAPCube), but here are some examples.
`getCell()` allows you to extract a single cell. The "total" cell for all facts where Priority = 1 can be found as follows:

    console.log(cube.getCell({Priority: 1}))
    # { ProjectHierarchy: null, Priority: 1, _count: 3, Scope: 30 }

Notice how the ProjectHierarchy field value is `null`. This is because it is a total cell for Priority dimension for all ProjectHierarchy values. Think of `null` values in this context as wildcards that indicate the total fields.

Similarly, we can get the total for all descendants of ProjectHierarchy = [1] regarless of Priority as follows:

    console.log(cube.getCell({ProjectHierarchy: [1]}))
    # { ProjectHierarchy: [ 1 ], Priority: null, _count: 3, Scope: 18 }

If you wanted the cell where ProjectHierarchy is [5] and priority is 1, that would just be:

    console.log(cube.getCell({ProjectHierarchy: [5], Priority: 1}))
    # { ProjectHierarchy: [ 5 ], Priority: 1, _count: 1, Scope: 17 }

`getCell()` uses the cellIndex so it's very efficient. Using `getCell()` and `getDimensionValues()`, you can extract exactly what you want from the OLAPCube or you can use the `slice()` method to pull out the data in a format that is ideally suited to graphing.
    
You can call the `toString()` method which extracts a 1D or 2D slice for tabular display. 

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
materialized path array. This approach is commonly used with NoSQL databases like
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


## Changelog ##

* 0.2.2 - 2015-07-09 - Documentation upgrades and more testing
* 0.2.1 - 2015-07-07 - Documentation tweaks
* 0.2.0 - 2015-07-07 - Tests using documentdb-mock, syntactic sugar for groupBy
* 0.1.0 - 2015-05-10 - Initial release


## Contributing to documentdb-lumenize ##

At this point, I have a pretty long list of things to add to documentdb-lumenize. Namely the time-series calculators from Lumenize. 

Before I do all that, I want to do some performance and load testing. My theory is that moving the code to the data rather than streaming the data out over the wire for analysis will be much more efficient, but the execution semantics of stored procedures isolation as well as RU based throttling differences could possibly make it slower. I need to setup a way for testing this. Any help with this sort of load testing would be greatly appreciated.


## License ##

Free for evaluation or non-commercial purposes. Contact me for other licensing.





