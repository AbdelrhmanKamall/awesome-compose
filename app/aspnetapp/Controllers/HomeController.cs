using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Distributed;
using aspnetapp.Models;

namespace aspnetapp.Controllers
{
    public class HomeController : Controller
    {
        private readonly IDistributedCache _cache;

        public HomeController(IDistributedCache cache)
        {
            _cache = cache;
        }

        public IActionResult Index()
        {
            return View();
        }

        public IActionResult About()
        {
            // Check if the cached data exists
            string cachedData = _cache.GetString("AboutData");
            if (cachedData == null)
            {
                // If not in cache, generate or fetch the data from the database or other source
                ViewData["Message"] = "Your application description page.";
                cachedData = ViewData["Message"].ToString();

                // Cache the data for 10 minutes (600 seconds)
                var cacheOptions = new DistributedCacheEntryOptions
                {
                    AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(10)
                };

                // Store the data in the cache
                _cache.SetString("AboutData", cachedData, cacheOptions);
            }
            else
            {
                // If the data is in cache, use the cached data
                ViewData["Message"] = cachedData;
            }

            return View();
        }

        public IActionResult Contact()
        {
            ViewData["Message"] = "Your contact page.";

            return View();
        }

        public IActionResult Privacy()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
