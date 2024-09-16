namespace src.Models
{
    public class SensorData
    {
        public double Temperature { get; set; }
        public double Pressure { get; set; }
        public double Altitude { get; set; }
        public double SeaPressure { get; set; }
        public Orientation Orientation { get; set; }
        public Position Position { get; set; }
        public GPS GPS { get; set; }
    }

    public class Orientation
    {
        public double X { get; set; }
        public double Y { get; set; }
        public double Z { get; set; }
    }

    public class Position
    {
        public double X { get; set; }
        public double Y { get; set; }
        public double Z { get; set; }
    }

    public class GPS
    {
        public double Latitude { get; set; }
        public double Longitude { get; set; }
        public double Altitude { get; set; }
        public double Speed { get; set; }
        public int Satellites { get; set; }
        public double HDOP { get; set; }
        public double VDOP { get; set; }
        public double PDOP { get; set; }
    }
}
