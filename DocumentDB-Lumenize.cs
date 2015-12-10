using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

using Microsoft.Azure.Documents;
using Microsoft.Azure.Documents.Client;
using Microsoft.Azure.Documents.Linq;
using Newtonsoft.Json;
using System.IO;
using System.Net;

namespace DocumentDB_Lumenize
{
    class Program
    {
        static string EndpointUrl = Environment.GetEnvironmentVariable("DOCUMENT_DB_URL");
        static string AuthorizationKey = Environment.GetEnvironmentVariable("DOCUMENT_DB_KEY");

        public static async Task<dynamic> executeUntilNoContinuation(DocumentClient client, dynamic config)
        {

            dynamic result = null;
            var queryDone = false;
            while (!queryDone)
            {
                try
                {
                    result = await client.ExecuteStoredProcedureAsync<dynamic>("dbs/dev-test-database/colls/dev-test-collection/sprocs/cube", config);
                    config = result.Response;
                    queryDone = true;
                }
                catch (DocumentClientException documentClientException)
                {
                    var statusCode = (int)documentClientException.StatusCode;
                    if (statusCode == 429 || statusCode == 503)
                        System.Threading.Thread.Sleep(documentClientException.RetryAfter);
                    else
                        throw;
                }
                catch (AggregateException aggregateException)
                {
                    if (aggregateException.InnerException.GetType() == typeof(DocumentClientException))
                    {

                        var docExcep = aggregateException.InnerException as DocumentClientException;
                        var statusCode = (int)docExcep.StatusCode;
                        if (statusCode == 429 || statusCode == 503)
                            System.Threading.Thread.Sleep(docExcep.RetryAfter);
                        else
                            throw;
                    }
                }
            }

            if (config.continuation == null)
                return config;
            else
                return executeUntilNoContinuation(client, config);
        }

        private static async Task GetStartedDemo()
        {
            // Create a new instance of the DocumentClient
            var client = new DocumentClient(new Uri(EndpointUrl), AuthorizationKey);

            // Check to verify a database with the id=FamilyRegistry does not exist
            string databaseId = "dev-test-database";
            string databaseLink = "dbs/" + databaseId;
            Database database = client.CreateDatabaseQuery().Where(db => db.Id == databaseId).AsEnumerable().FirstOrDefault();

            // If the database does not exist, create a new database
            if (database == null)
            {
                database = await client.CreateDatabaseAsync(
                    new Database
                    {
                        Id = databaseId
                    });
            }

            // Write the new database's id to the console
            Console.WriteLine(database.Id);

            // Check to verify a document collection with the id=FamilyCollection does not exist
            string collectionId = "dev-test-collection";
            string collectionLink = databaseLink + "/colls/" + collectionId;
            DocumentCollection documentCollection = client.CreateDocumentCollectionQuery("dbs/" + database.Id).Where(c => c.Id == collectionId).AsEnumerable().FirstOrDefault();

            // If the document collection does not exist, create a new collection
            if (documentCollection == null)
            {
                documentCollection = await client.CreateDocumentCollectionAsync("dbs/" + database.Id,
                    new DocumentCollection
                    {
                        Id = collectionId
                    });
            }

            // Write the new collection's id to the console
            Console.WriteLine(documentCollection.Id);

            // Create some documents
            string doc1s = @"{
                state: 'doing',
                points: 5
            }";
            Object doc1o = JsonConvert.DeserializeObject<Object>(doc1s);
            Document doc1 = await client.UpsertDocumentAsync(documentCollection.SelfLink, doc1o);

            string doc2s = @"{
                state: 'doing',
                points: 50
            }";
            Object doc2o = JsonConvert.DeserializeObject<Object>(doc2s);
            Document doc2 = await client.UpsertDocumentAsync(documentCollection.SelfLink, doc2o);

            string doc3s = @"{
                state: 'done',
                points: 500
            }";
            Object doc3o = JsonConvert.DeserializeObject<Object>(doc3s);
            Document doc3 = await client.UpsertDocumentAsync(documentCollection.SelfLink, doc3o);

            // Check if a stored procedure with the id=cube exists
            StoredProcedure sproc = client.CreateStoredProcedureQuery("dbs/" + database.Id + "/colls/" + documentCollection.Id).Where(c => c.Id == "cube").AsEnumerable().FirstOrDefault();

            // If the stored procedure does not exist, create a new one
            if (sproc == null)
            {
                // Get the cube.string file from documentdb-lumenize GitHub repository
                Uri uri = new System.Uri("https://raw.githubusercontent.com/lmaccherone/documentdb-lumenize/master/sprocs/cube.string");
                WebClient wc = new WebClient();
                Stream stream = wc.OpenRead(uri);
                StreamReader sr = new StreamReader(stream);
                string sprocString = await sr.ReadToEndAsync();
                stream.Close();

                // Upload the cube sproc to your collection
                sproc = await client.UpsertStoredProcedureAsync(documentCollection.SelfLink,
                    new StoredProcedure
                    {
                        Id = "cube",
                        Body = sprocString
                    });
            }

            // Write the sproc's id to the console
            Console.WriteLine(sproc.Id);

            // Create config for executing sproc
            string configString = @"{
                cubeConfig: {
                    groupBy: 'state',
                    field: 'points',
                    f: 'sum'
                },
                filterQuery: 'SELECT * FROM c',
                continuation: null
            }";
            dynamic config = JsonConvert.DeserializeObject<Object>(configString);
            Console.WriteLine(config);

            config = await executeUntilNoContinuation(client, config);

            Console.WriteLine();
            Console.WriteLine("resulting config");
            Console.WriteLine(config);

            Console.WriteLine();
            Console.WriteLine(config.continuation == null);

            Console.WriteLine("Press any key to continue ...");
            Console.ReadKey();
            Console.Clear();
        }

        public static void Main(string[] args)
        {
            try
            {
                GetStartedDemo().Wait();
            }
            catch (Exception e)
            {
                Exception baseException = e.GetBaseException();
                Console.WriteLine("Error: {0}, Message: {1}", e.Message, baseException.Message);
            }
        }
    }
}
