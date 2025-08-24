using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using System.Text.Json;

namespace TestDataGenerator
{
    class Program
    {
        private static readonly HttpClient httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
        private static string baseUrl = "http://localhost:5000";
        private static string testType = "all";

        static async Task Main(string[] args)
        {
            if (args.Length > 0)
            {
                baseUrl = args[0];
            }
            if (args.Length > 1)
            {
                testType = args[1].ToLower();
            }

            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("\n=== Advanced Bug Hunter - Observability Exercises ===");
            Console.ResetColor();
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"Target: {baseUrl}");
            Console.WriteLine($"Test Type: {testType}");
            Console.ResetColor();

            Console.WriteLine("\nStarting bug hunting...");

            try
            {
                switch (testType)
                {
                    case "random":
                        await TestRandomProductIds();
                        break;
                    case "range":
                        await TestOrderRanges();
                        break;
                    case "prime":
                        await TestPrimeNumbers();
                        break;
                    case "load":
                        await TestLoadPattern();
                        break;
                    case "palindrome":
                        await TestPalindromePattern();
                        break;
                    case "edge":
                        await TestEdgeCases();
                        break;
                    case "all":
                        await TestRandomProductIds();
                        await Task.Delay(2000);
                        await TestOrderRanges();
                        await Task.Delay(2000);
                        await TestPrimeNumbers();
                        await Task.Delay(2000);
                        await TestLoadPattern();
                        await Task.Delay(2000);
                        await TestPalindromePattern();
                        await Task.Delay(2000);
                        await TestEdgeCases();
                        break;
                    default:
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("Invalid test type. Use: random, range, prime, load, palindrome, edge, or all");
                        Console.ResetColor();
                        return;
                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"\nError during testing: {ex.Message}");
                Console.ResetColor();
            }

            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("\n=== Bug Hunter Complete ===");
            Console.ResetColor();
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine("Check Application Insights for detailed telemetry and code locations!");
            Console.ResetColor();
            Console.ForegroundColor = ConsoleColor.Cyan;
            Console.WriteLine("\n🔍 Code-Level Analysis:");
            Console.ResetColor();
            Console.WriteLine("All bugs now include exact file names and line numbers in Application Insights");
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("Look for 'BugTriggered' events with CodeLocation dimensions");
            Console.ResetColor();
        }

        static async Task TestRandomProductIds()
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n[TEST 1] Random Product ID Performance Test");
            Console.ResetColor();
            Console.WriteLine("Testing 100 random product IDs to find performance anomalies...");

            var slowRequests = new List<(int id, double duration)>();
            var normalRequests = new List<(int id, double duration)>();
            var random = new Random();

            // Include some known unlucky numbers to ensure we find patterns
            var unluckyNumbers = new[] { 13, 42, 99, 666, 675, 777, 1337, 2024, 9999 };
            var testIds = new List<int>();
            
            // Add some unlucky numbers to guarantee we find them
            testIds.AddRange(unluckyNumbers.Take(4));
            
            // Add random numbers for the rest
            for (int i = testIds.Count; i < 100; i++)
            {
                testIds.Add(random.Next(1, 10000));
            }
            
            // Shuffle the list so unlucky numbers aren't obviously first
            for (int i = 0; i < testIds.Count; i++)
            {
                int j = random.Next(i, testIds.Count);
                (testIds[i], testIds[j]) = (testIds[j], testIds[i]);
            }
            
            for (int i = 1; i <= 100; i++)
            {
                int id = testIds[i - 1];
                var sw = Stopwatch.StartNew();

                try
                {
                    var response = await httpClient.GetAsync($"{baseUrl}/gateway/products/{id}");
                    sw.Stop();
                    var duration = sw.ElapsedMilliseconds;

                    if (duration > 2000)
                    {
                        slowRequests.Add((id, duration));
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.Write("!");
                    }
                    else
                    {
                        normalRequests.Add((id, duration));
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.Write(".");
                    }
                    Console.ResetColor();
                }
                catch
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.Write("X");
                    Console.ResetColor();
                }

                if (i % 50 == 0) Console.Write($" {i}/100");
            }

            Console.WriteLine("\n\nResults:");
            if (slowRequests.Count > 0)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"Found {slowRequests.Count} slow requests:");
                foreach (var req in slowRequests)
                {
                    Console.WriteLine($"  Product ID {req.id}: {req.duration:F0}ms");
                }
                Console.ResetColor();

                var slowIds = string.Join(", ", slowRequests.Select(r => r.id));
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"\nSlow Product IDs: {slowIds}");
                Console.ForegroundColor = ConsoleColor.Cyan;
                Console.WriteLine("Hypothesis: Check if these IDs have something in common (unlucky numbers?)");
                Console.ResetColor();
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine("All requests performed normally");
                Console.ResetColor();
            }

            if (normalRequests.Count > 0)
            {
                var avgNormal = normalRequests.Average(r => r.duration);
                Console.ForegroundColor = ConsoleColor.Green;
                Console.WriteLine($"Average normal response time: {avgNormal:F0}ms");
                Console.ResetColor();
            }
        }

        static async Task TestOrderRanges()
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n[TEST 2] Sequential Order Range Test");
            Console.ResetColor();
            Console.WriteLine("Testing order IDs from 900 to 1200 to find failure patterns...");

            var failures = new List<int>();
            var successes = new List<int>();

            for (int id = 900; id <= 1200; id++)
            {
                try
                {
                    var response = await httpClient.PostAsync($"{baseUrl}/gateway/orders?orderId={id}", null);
                    if (response.IsSuccessStatusCode)
                    {
                        successes.Add(id);
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.Write(".");
                    }
                    else
                    {
                        failures.Add(id);
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.Write("X");
                    }
                    Console.ResetColor();
                }
                catch
                {
                    failures.Add(id);
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.Write("X");
                    Console.ResetColor();
                }

                if (id % 50 == 0) Console.Write($" {id}");
            }

            Console.WriteLine("\n\nResults:");
            if (failures.Count > 0)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine($"Failed order IDs: {failures.Count} failures");
                Console.ResetColor();

                var ranges = new List<string>();
                if (failures.Count > 0)
                {
                    int start = failures[0];
                    int end = failures[0];

                    for (int i = 1; i < failures.Count; i++)
                    {
                        if (failures[i] == end + 1)
                        {
                            end = failures[i];
                        }
                        else
                        {
                            if (end - start >= 10)
                            {
                                ranges.Add($"[{start}-{end}]");
                            }
                            start = failures[i];
                            end = failures[i];
                        }
                    }
                    if (end - start >= 10)
                    {
                        ranges.Add($"[{start}-{end}]");
                    }
                }

                if (ranges.Count > 0)
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.WriteLine($"Failure ranges detected: {string.Join(", ", ranges)}");
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("Hypothesis: Check if specific ID ranges have processing issues");
                    Console.ResetColor();
                }
            }

            double failureRate = (failures.Count / 301.0) * 100;
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"Overall failure rate: {failureRate:F2}%");
            Console.ResetColor();
        }

        static async Task TestPrimeNumbers()
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n[TEST 3] Prime Number Pattern Test");
            Console.ResetColor();
            Console.WriteLine("Testing prime number IDs for memory anomalies...");
            Console.WriteLine("Note: Prime number IDs may accumulate memory over time due to caching behavior");

            int[] primes = { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47 };
            int[] nonPrimes = { 4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25 };

            Console.WriteLine("Testing prime IDs (memory leak suspects)...");
            var primeResults = new List<(int id, double duration)>();
            foreach (int id in primes)
            {
                try
                {
                    var sw = Stopwatch.StartNew();
                    var response = await httpClient.GetAsync($"{baseUrl}/gateway/products/{id}");
                    sw.Stop();
                    primeResults.Add((id, sw.ElapsedMilliseconds));
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.Write(".");
                    Console.ResetColor();
                }
                catch
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.Write("X");
                    Console.ResetColor();
                }
            }

            Console.WriteLine("\nTesting non-prime IDs...");
            var nonPrimeResults = new List<(int id, double duration)>();
            foreach (int id in nonPrimes)
            {
                try
                {
                    var sw = Stopwatch.StartNew();
                    var response = await httpClient.GetAsync($"{baseUrl}/gateway/products/{id}");
                    sw.Stop();
                    nonPrimeResults.Add((id, sw.ElapsedMilliseconds));
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.Write(".");
                    Console.ResetColor();
                }
                catch
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.Write("X");
                    Console.ResetColor();
                }
            }

            Console.WriteLine("\n\nResults:");

            if (primeResults.Count > 0 && nonPrimeResults.Count > 0)
            {
                var avgPrime = primeResults.Average(r => r.duration);
                var avgNonPrime = nonPrimeResults.Average(r => r.duration);

                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"Average prime ID response time: {avgPrime:F0}ms");
                Console.WriteLine($"Average non-prime ID response time: {avgNonPrime:F0}ms");
                Console.ResetColor();

                if (avgPrime > avgNonPrime * 1.5)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("WARNING: Prime number IDs show performance degradation!");
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("Hypothesis: Check memory usage patterns for prime IDs");
                    Console.ResetColor();
                }
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Unable to calculate averages - insufficient data");
                Console.ResetColor();
            }
        }

        static async Task TestLoadPattern()
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n[TEST 4] Load Pattern Test");
            Console.ResetColor();
            Console.WriteLine("Sending 50 rapid requests to find thread pool issues...");

            var results = new List<(int request, double duration)>();
            for (int i = 1; i <= 60; i++)
            {
                var sw = Stopwatch.StartNew();
                try
                {
                    var response = await httpClient.PostAsync($"{baseUrl}/gateway/orders", null);
                    sw.Stop();
                    var duration = sw.ElapsedMilliseconds;
                    results.Add((i, duration));

                    if (duration > 3000)
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.Write("S");
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.Write(".");
                    }
                    Console.ResetColor();
                }
                catch
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.Write("X");
                    Console.ResetColor();
                }
            }

            Console.WriteLine("\n\nResults:");
            var slowRequests = results.Where(r => r.duration > 3000).ToList();
            if (slowRequests.Count > 0)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Slow requests detected at positions:");
                foreach (var req in slowRequests)
                {
                    Console.WriteLine($"  Request #{req.request}: {req.duration:F0}ms");
                }
                Console.ResetColor();

                var positions = slowRequests.Select(r => r.request).ToList();
                var modulo10 = positions.Where(p => p % 10 == 0).Count();
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"Requests that are multiples of 10: {modulo10} out of {slowRequests.Count} slow requests");
                var positionText = string.Join(", ", positions);
                Console.WriteLine($"Slow request positions: {positionText}");
                Console.ResetColor();
                
                if (modulo10 >= slowRequests.Count * 0.6) // At least 60% are multiples of 10
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("PATTERN DETECTED: Most slow requests are multiples of 10!");
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("Hypothesis: Thread pool exhaustion pattern");
                    Console.ResetColor();
                }
            }
        }

        static async Task TestPalindromePattern()
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n[TEST 5] Palindrome Pattern Test");
            Console.ResetColor();
            Console.WriteLine("Testing palindrome IDs for CPU spike issues...");

            int[] palindromes = { 11, 22, 33, 44, 55, 66, 77, 88, 99, 101, 111, 121, 131, 141, 151, 161, 171, 181, 191, 202, 212, 222, 232, 242, 252, 1001, 1111, 1221, 1331, 1441, 1551, 1661, 1771, 1881, 1991, 2002, 2112, 2222, 2332, 2442 };
            int[] nonPalindromes = { 10, 12, 13, 14, 15, 16, 17, 18, 19, 20, 23, 24, 25, 26, 27, 28, 29, 30, 100, 102, 103, 104, 105, 106, 107, 108, 109, 110, 112, 113, 114, 115 };

            Console.WriteLine("Testing palindrome IDs...");
            var palindromeResults = new List<(int id, double duration)>();
            foreach (int id in palindromes.Take(15))
            {
                try
                {
                    var sw = Stopwatch.StartNew();
                    var response = await httpClient.GetAsync($"{baseUrl}/gateway/products/{id}");
                    sw.Stop();
                    var duration = sw.ElapsedMilliseconds;
                    palindromeResults.Add((id, duration));

                    if (duration > 5000)
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.Write("!");
                    }
                    else
                    {
                        Console.ForegroundColor = ConsoleColor.Green;
                        Console.Write(".");
                    }
                    Console.ResetColor();
                }
                catch
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.Write("X");
                    Console.ResetColor();
                }
            }

            Console.WriteLine("\nTesting non-palindrome IDs...");
            var nonPalindromeResults = new List<(int id, double duration)>();
            foreach (int id in nonPalindromes.Take(15))
            {
                try
                {
                    var sw = Stopwatch.StartNew();
                    var response = await httpClient.GetAsync($"{baseUrl}/gateway/products/{id}");
                    sw.Stop();
                    nonPalindromeResults.Add((id, sw.ElapsedMilliseconds));
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.Write(".");
                    Console.ResetColor();
                }
                catch
                {
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    Console.Write("X");
                    Console.ResetColor();
                }
            }

            Console.WriteLine("\n\nResults:");

            if (palindromeResults.Count > 0 && nonPalindromeResults.Count > 0)
            {
                var avgPalindrome = palindromeResults.Average(r => r.duration);
                var avgNonPalindrome = nonPalindromeResults.Average(r => r.duration);

                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine($"Average palindrome ID response time: {avgPalindrome:F0}ms");
                Console.WriteLine($"Average non-palindrome ID response time: {avgNonPalindrome:F0}ms");
                Console.ResetColor();

                if (avgPalindrome > avgNonPalindrome * 10)
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("CRITICAL: Palindrome IDs cause extreme CPU spikes!");
                    var ratio = avgPalindrome / avgNonPalindrome;
                    Console.WriteLine($"Palindrome requests take {ratio:F0}x longer!");
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("Hypothesis: CPU-intensive processing for palindrome patterns");
                    Console.ResetColor();

                    var slowPalindromes = palindromeResults.Where(r => r.duration > 5000).ToList();
                    if (slowPalindromes.Count > 0)
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("\nExtremely slow palindrome IDs:");
                        foreach (var req in slowPalindromes)
                        {
                            Console.WriteLine($"  ID {req.id}: {req.duration:F0}ms");
                        }
                        Console.ResetColor();
                    }
                }
            }
            else
            {
                Console.ForegroundColor = ConsoleColor.Yellow;
                Console.WriteLine("Unable to calculate averages - insufficient data");
                Console.ResetColor();
            }
        }

        static async Task TestEdgeCases()
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.WriteLine("\n[TEST 6] Edge Case Test");
            Console.ResetColor();
            Console.WriteLine("Testing edge cases (0, negative, very large IDs)...");

            int[] edgeCases = { 0, -1, -100, 999999, 2147483647 };
            var results = new List<(int id, string status, string data)>();

            foreach (int id in edgeCases)
            {
                Console.WriteLine($"\nTesting Product ID {id}...");
                try
                {
                    var response = await httpClient.GetAsync($"{baseUrl}/gateway/products/{id}");
                    var content = await response.Content.ReadAsStringAsync();
                    results.Add((id, "Success", content));
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("  Success");
                    Console.ResetColor();

                    if (content.Contains("CORRUPTED_DATA") || content.Contains("\"price\":-1"))
                    {
                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("  WARNING: Data corruption detected!");
                        Console.ForegroundColor = ConsoleColor.Yellow;
                        
                        try
                        {
                            var json = JsonDocument.Parse(content);
                            if (json.RootElement.TryGetProperty("name", out var name))
                                Console.WriteLine($"  Product name: {name.GetString()}");
                            if (json.RootElement.TryGetProperty("price", out var price))
                                Console.WriteLine($"  Product price: {price.GetDecimal()}");
                        }
                        catch { }
                        Console.ResetColor();
                    }
                }
                catch (Exception ex)
                {
                    results.Add((id, "Failed", ex.Message));
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine($"  Failed: {ex.Message}");
                    Console.ResetColor();
                }
            }

            Console.WriteLine("\nTesting normal request after edge cases...");
            try
            {
                var response = await httpClient.GetAsync($"{baseUrl}/gateway/products/100");
                var content = await response.Content.ReadAsStringAsync();
                if (content.Contains("CORRUPTED_DATA"))
                {
                    Console.ForegroundColor = ConsoleColor.Red;
                    Console.WriteLine("CACHE POISONING DETECTED: Normal requests returning corrupted data!");
                    Console.ForegroundColor = ConsoleColor.Cyan;
                    Console.WriteLine("Hypothesis: Edge case IDs corrupt the cache");
                    Console.ResetColor();
                }
                else
                {
                    Console.ForegroundColor = ConsoleColor.Green;
                    Console.WriteLine("Normal request OK");
                    Console.ResetColor();
                }
            }
            catch
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine("Normal request failed");
                Console.ResetColor();
            }
        }
    }
}
