namespace api;

public class RateLimitingMiddleware(RequestDelegate next)
{
    private static readonly Dictionary<string, List<DateTime>> _requestTimes = new();
    private static readonly TimeSpan _timeSpan = TimeSpan.FromMinutes(1);
    private static readonly int _maxRequests = 100;
    private static readonly object _lock = new();

    public async Task InvokeAsync(HttpContext context)
    {
        var clientIp = context.Connection.RemoteIpAddress?.ToString();

        if (clientIp == null)
        {
            context.Response.StatusCode = StatusCodes.Status400BadRequest;
            await context.Response.WriteAsync("Unable to determine client IP.");
            return;
        }

        lock (_lock)
        {
            if (!_requestTimes.ContainsKey(clientIp))
            {
                _requestTimes[clientIp] = new List<DateTime>();
            }

            var requestTimes = _requestTimes[clientIp];
            var currentTime = DateTime.UtcNow;

            requestTimes.RemoveAll(time => time < currentTime - _timeSpan);

            if (requestTimes.Count >= _maxRequests)
            {
                context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
                context.Response.WriteAsync("Too many requests.").Wait();
                return;
            }

            requestTimes.Add(currentTime);
        }

        await next(context);
    }
}