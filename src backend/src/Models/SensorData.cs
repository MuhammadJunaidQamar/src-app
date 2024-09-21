namespace src.Models
{
    public class SensorData
    {
        public double Temperature { get; set; }
        public double Pressure { get; set; }
        public double Altitude { get; set; }
        public double SeaPressure { get; set; }
        public Acceleration Acceleration { get; set; }
        public Rotation Rotation { get; set; }
        public Distance Distance { get; set; }
        public GPS GPS { get; set; }
    }

    public class Acceleration
    {
        public double X { get; set; }
        public double Y { get; set; }
        public double Z { get; set; }
    }

    public class Rotation
    {
        public double X { get; set; }
        public double Y { get; set; }
        public double Z { get; set; }
    }

    public class Distance
    {
        public double X { get; set; }
        public double Y { get; set; }
        public double Z { get; set; }
    }

    public class GPS
    {
        public double Heading { get; set; }
        public int NoOfSatellites { get; set; }
        public double Longitude { get; set; }
        public double Latitude { get; set; }
        public double Altitude { get; set; }
    }
}
