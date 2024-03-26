using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using Azure.Storage.Blobs;
using Azure.Storage.Blobs.Models;
using Microsoft.Extensions.Configuration;
using System.Text;

namespace OrderItemsReserver.Function
{
    public class OrderItemsReserver_HttpTrigger
    {
        private readonly ILogger<OrderItemsReserver_HttpTrigger> _logger;
        private readonly BlobServiceClient _blobServiceClient;

        public OrderItemsReserver_HttpTrigger(ILogger<OrderItemsReserver_HttpTrigger> logger, BlobServiceClient blobServiceClient)
        {
            _logger = logger;
            _blobServiceClient = blobServiceClient;
        }

        [Function("OrderItemsReserver_HttpTrigger")]
        public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "reserveitems")] HttpRequestData req,
             FunctionContext executionContext)
        {
            try
            {
                _logger.LogInformation("C# HTTP trigger function processed a request.");

                // Read and parse the order details from the HTTP POST request.
                using var reader = new StreamReader(req.Body);
                var requestBody = await reader.ReadToEndAsync();
                var orderDetails = JsonSerializer.Deserialize<OrderDetails>(requestBody);

                if (orderDetails == null)
                {
                    _logger.LogError("Failed to parse order details.");
                    return new BadRequestObjectResult("Failed to parse order details.");
                }

                _logger.LogInformation($"Parsed order details: OrderDate = {orderDetails.OrderDate}, Items count = {orderDetails.OrderItems?.Length}");

                // Connect to the specified Blob Storage container.
                string containerName = "orderitems";
                var containerClient = _blobServiceClient.GetBlobContainerClient(containerName);
                await containerClient.CreateIfNotExistsAsync(PublicAccessType.None);

                _logger.LogInformation($"Connected to Blob Storage container: {containerName}");

                // Upload the JSON file with the order details.
                string jsonFilename = $"order-{orderDetails.OrderDate}.json";
                var blobClient = containerClient.GetBlobClient(jsonFilename);
                using var jsonStream = new MemoryStream(Encoding.UTF8.GetBytes(requestBody));
                await blobClient.UploadAsync(jsonStream, new BlobUploadOptions { HttpHeaders = new BlobHttpHeaders { ContentType = "application/json" } });

                _logger.LogInformation($"Uploaded JSON file: {jsonFilename}");

                return new OkObjectResult($"Order {orderDetails.OrderDate} has been processed.");
            }
            catch (Exception ex)
            {
                _logger.LogError($"An error occurred: {ex.Message}. Stack trace: {ex.StackTrace}");
                return new ObjectResult($"An error occurred: {ex.Message}") { StatusCode = StatusCodes.Status500InternalServerError };
            }
        }
    }

    public class OrderDetails
    {
        public string? OrderDate { get; set; } 
        public OrderItem[]? OrderItems { get; set; }
    }

    public class OrderItem
    {
        public int ProductId { get; set; }
        public int Units { get; set; }
    }
}
