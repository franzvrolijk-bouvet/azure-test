public class RateLimitingMiddleware(RequestDelegate next)
{
    private static DateTime _lastRequestTime = DateTime.MinValue;
    private static TimeSpan _timeSpan = TimeSpan.FromSeconds(10);
    private static readonly object _lock = new();

    public async Task InvokeAsync(HttpContext context)
    {
        lock (_lock)
        {
            if (DateTime.UtcNow - _lastRequestTime < _timeSpan)
            {
                context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
                context.Response.WriteAsync("Too many requests.").Wait();
                return;
            }

            _lastRequestTime = DateTime.UtcNow;
        }

        await next(context);
    }
}