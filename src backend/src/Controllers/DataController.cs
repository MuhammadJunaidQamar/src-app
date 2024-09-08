using Microsoft.AspNetCore.Mvc;
using Microsoft.OpenApi.Any;
using src.Models;

namespace src.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DataController : Controller
    {
        // Expose an endpoint to retrieve the latest message
        [HttpGet("GetLatestData")]
        public IActionResult GetLatestMessage(string Type)
        {
            if (Type == null)
                return StatusCode(StatusCodes.Status400BadRequest, "Data not specified");

            DataResponse responseBody = new();

            if (!string.IsNullOrEmpty(LastMessageModel.LastMessage) && Type == "temperature")
            {
                responseBody.Temperature = LastMessageModel.LastMessage;
                return Ok(responseBody);
            }
            
            LastMessageModel.LastMessage = "Esp32 not online";
            
            responseBody.Temperature = LastMessageModel.LastMessage;
            return Ok(responseBody);
        }
    }
}
