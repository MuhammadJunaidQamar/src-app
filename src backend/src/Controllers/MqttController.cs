using Microsoft.AspNetCore.Mvc;

namespace src.Controllers
{
    public class MqttController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}
