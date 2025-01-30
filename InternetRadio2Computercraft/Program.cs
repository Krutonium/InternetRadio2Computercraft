using System.Diagnostics;
using System.Net;
using System.Net.WebSockets;
using System.Text;

namespace InternetRadio2Computercraft
{
    class Program
    {
        static async Task Main(string[] args)
        {
            HttpListener listener = new HttpListener();

            listener.Prefixes.Add("http://*:2468/");
            listener.Start();
            Console.WriteLine("Server started, listening on port 2468...");

            while (true)
            {
                HttpListenerContext context = await listener.GetContextAsync();
                _ = Task.Run(() => ProcessRequest(context));
            }
        }

        private static async Task ProcessRequest(HttpListenerContext context)
        {
            if (context.Request.IsWebSocketRequest)
            {
                await HandleWebSocket(context);
            }
            else
            {
                context.Response.StatusCode = 400;
                using (StreamWriter writer = new StreamWriter(context.Response.OutputStream))
                {
                    await writer.WriteAsync("WebSocket connection required.");
                }

                context.Response.Close();
            }
        }

        private static async Task HandleWebSocket(HttpListenerContext context)
        {
            WebSocket webSocket = (await context.AcceptWebSocketAsync(subProtocol: null)).WebSocket;

            Console.WriteLine("WebSocket connection established.");

            // Expect the URL in a WebSocket message
            var buffer = new byte[1024];
            var result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
            string url = Encoding.UTF8.GetString(buffer, 0, result.Count);

            if (string.IsNullOrWhiteSpace(url) || url.Contains("..") || url.Contains("file://"))
            {
                Console.WriteLine("Invalid URL.");
                await webSocket.CloseAsync(WebSocketCloseStatus.InvalidMessageType, "Invalid URL",
                    CancellationToken.None);
                return;
            }

            Console.WriteLine($"Streaming from URL: {url}");

            using (var ffmpeg = new Process())
            {
                using (var ytdlp = new Process())
                {

                    // Adjusted to use yt-dlp in front of ffmpeg
                    ffmpeg.StartInfo.FileName = "./encode.sh";
                    ffmpeg.StartInfo.Arguments = $"\"{url}\"";
                    ffmpeg.StartInfo.RedirectStandardOutput = true;
                    ffmpeg.StartInfo.UseShellExecute = false;
                    ffmpeg.StartInfo.CreateNoWindow = true;


                    try
                    {
                        var ffmpegOutput = ffmpeg.StandardOutput.BaseStream;
                        
                        var sendBuffer = new byte[4096];
                        int bytesRead;
                        int totalBytesRead = 0;

                        // Calculate the delay to maintain 48kbps (6KBps)
                        int targetBytesPerSecond = 6000;
                        int bufferSize = 4096;
                        double delayPerBuffer = (double)bufferSize / targetBytesPerSecond * 1000;


                        while ((bytesRead = await ffmpegOutput.ReadAsync(sendBuffer, totalBytesRead,
                                   sendBuffer.Length - totalBytesRead)) > 0)
                        {
                            totalBytesRead += bytesRead;

                            // Check if WebSocket is still open
                            if (webSocket.State != WebSocketState.Open)
                            {
                                Console.WriteLine("WebSocket disconnected.");
                                break;
                            }

                            // Send data if buffer is full
                            if (totalBytesRead >= 4096)
                            {
                                await webSocket.SendAsync(
                                    new ArraySegment<byte>(sendBuffer, 0, totalBytesRead),
                                    WebSocketMessageType.Binary,
                                    endOfMessage: true,
                                    CancellationToken.None
                                );
                                totalBytesRead = 0;
                                await Task.Delay((int)delayPerBuffer);
                            }
                        }

                        // Send any remaining data in the buffer
                        if (totalBytesRead > 0)
                        {
                            await webSocket.SendAsync(
                                new ArraySegment<byte>(sendBuffer, 0, totalBytesRead),
                                WebSocketMessageType.Binary,
                                endOfMessage: true,
                                CancellationToken.None
                            );
                        }
                    }
                    catch (WebSocketException wsEx)
                    {
                        Console.WriteLine($"WebSocket exception: {wsEx.Message}");
                        // Handle connection closure or cleanup
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Error streaming audio: {ex.Message}");
                    }
                    finally
                    {
                        if (!ffmpeg.HasExited)
                        {
                            ffmpeg.Kill();
                        }

                        ffmpeg.WaitForExit();
                        if (webSocket.State == WebSocketState.Open)
                        {
                            //await webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Streaming ended",
                            //    CancellationToken.None);
                        }

                        Console.WriteLine("WebSocket connection closed.");
                    }
                }
            }
        }
    }
}