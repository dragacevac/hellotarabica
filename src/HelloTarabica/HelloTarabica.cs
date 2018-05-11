namespace HelloTarabica
{
    using System.Net;
    using System.Net.Http;
    using System.Threading.Tasks;

    using Microsoft.Azure.WebJobs;
    using Microsoft.Azure.WebJobs.Extensions.Http;
    using Microsoft.Azure.WebJobs.Host;

    public static class Hello
    {
        [FunctionName("Hello")]
        public static async Task<HttpResponseMessage> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "hello")]
            HttpRequestMessage req,
            TraceWriter log)
        {
            const string Message = "Hello Tarabica 18!";

            return req.CreateResponse(HttpStatusCode.OK, Message);
        }
    }
}