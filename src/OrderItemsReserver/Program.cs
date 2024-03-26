using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Azure.Storage.Blobs;
using System;
using System.IO;
using System.Reflection;

var host = new HostBuilder()
    .ConfigureAppConfiguration(configurationBuilder =>
    {
        var currentDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        var settingsPath = Path.Combine(currentDirectory, "local.settings.json");
        configurationBuilder
            .AddJsonFile(settingsPath, optional: true, reloadOnChange: true)
            .AddEnvironmentVariables();
    })
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureServices((hostContext, services) =>
    {
        var configuration = hostContext.Configuration;

        string connectionString = configuration["Values:AzureWebJobsStorage"] 
                              ?? Environment.GetEnvironmentVariable("AzureWebJobsStorage");

        Console.WriteLine($"Connection String: {connectionString ?? "null"}");

        if (string.IsNullOrEmpty(connectionString))
        {
            throw new InvalidOperationException("Connection string is not set");
        }

        services.AddSingleton(x => new BlobServiceClient(connectionString));

        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
    })
    .Build();

host.Run();
