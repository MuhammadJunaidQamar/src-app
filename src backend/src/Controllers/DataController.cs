using Microsoft.AspNetCore.Mvc;
using src.Models;

namespace src.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DataController : Controller
    {
        // Expose an endpoint to retrieve the latest message
        [HttpGet("GetLatestData")]
        public IActionResult GetLatestMessage()
        {
            if (!string.IsNullOrEmpty(LastMessageModel.LastMessage))
            {
                return Ok(LastMessageModel.LastMessage);
            }
            return Ok(); // No message available
        }
    }
}
