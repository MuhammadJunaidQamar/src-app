using Microsoft.AspNetCore.Mvc;
using src.Models;
using System.Dynamic;

namespace src.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SensorDataController : ControllerBase
    {
        [HttpGet("GetLatestData")]
        public ActionResult<SensorData> GetSensorData(string? dataType)
        {
            if (string.IsNullOrEmpty(dataType))
                return StatusCode(StatusCodes.Status400BadRequest, "Data type not specified");

            if (string.IsNullOrEmpty(LastMessageModel.LastMessage))
                return StatusCode(StatusCodes.Status503ServiceUnavailable, "ESP32 not online");

            var data = LastMessageModel.LastMessage;
            string cleanData = data.Replace("/*", "").Replace("*/", "").Trim();
            string[] values = cleanData.Split(',');
            
            if (values.Length != 18)
                return StatusCode(StatusCodes.Status500InternalServerError, "Invalid data received");

            var sensorData = new SensorData
            {
                Temperature = double.Parse(values[0].Trim()),
                Pressure = double.Parse(values[1].Trim()),
                Altitude = double.Parse(values[2].Trim()),
                SeaPressure = double.Parse(values[3].Trim()),
                Acceleration = new Acceleration
                {
                    X = double.Parse(values[4].Trim()),
                    Y = double.Parse(values[5].Trim()),
                    Z = double.Parse(values[6].Trim())
                },
                Rotation = new Rotation
                {
                    X = double.Parse(values[7].Trim()),
                    Y = double.Parse(values[8].Trim()),
                    Z = double.Parse(values[9].Trim())
                },
                Distance = new Distance
                {
                    X = double.Parse(values[10].Trim()),
                    Y = double.Parse(values[11].Trim()),
                    Z = double.Parse(values[12].Trim())
                },
                GPS = new GPS
                {
                    Heading = double.Parse(values[13].Trim()),
                    NoOfSatellites = int.Parse(values[14].Trim()),
                    Longitude = double.Parse(values[15].Trim()),
                    Latitude = double.Parse(values[16].Trim()),
                    Altitude = double.Parse(values[17].Trim()),
                }
            };
            dynamic responseBody = new ExpandoObject();
            switch (dataType)
            {
                case "All":
                    responseBody = sensorData;
                    break;
                case "Temperature":
                    responseBody.Temperature = sensorData.Temperature;
                    break;
                case "Pressure":
                    responseBody.Pressure = sensorData.Pressure;
                    break;
                case "Altitude":
                    responseBody.Altitude = sensorData.Altitude;
                    break;
                case "SeaPressure":
                    responseBody.SeaPressure = sensorData.SeaPressure;
                    break;
                case "Acceleration":
                    responseBody.Acceleration = sensorData.Acceleration;
                    break;
                case "Rotation":
                    responseBody.Rotation = sensorData.Rotation;
                    break;
                case "Distance":
                    responseBody.Distance = sensorData.Distance;
                    break;
                case "Gps":
                    responseBody.GPS = sensorData.GPS;
                    break;
                default:
                    return StatusCode(StatusCodes.Status422UnprocessableEntity, "Invalid data type requested");
            }
            return Ok(responseBody);  // return StatusCode(StatusCodes.Status200OK, responseBody);
        }
    }
}
