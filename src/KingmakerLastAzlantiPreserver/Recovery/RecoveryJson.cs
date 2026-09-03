using System;
using System.IO;
using System.Runtime.Serialization.Json;

namespace KingmakerLastAzlantiPreserver.Recovery
{
    internal static class RecoveryJson
    {
        public static void Write<T>(string path, T value)
        {
            DataContractJsonSerializer serializer = new DataContractJsonSerializer(typeof(T));
            using (FileStream stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                serializer.WriteObject(stream, value);
                stream.Flush(true);
            }
        }

        public static bool TryRead<T>(string path, out T value, out string error)
        {
            value = default(T);
            error = null;
            try
            {
                DataContractJsonSerializer serializer = new DataContractJsonSerializer(typeof(T));
                using (FileStream stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read))
                {
                    object deserialized = serializer.ReadObject(stream);
                    if (!(deserialized is T))
                    {
                        error = "JSON did not contain " + typeof(T).Name + ".";
                        return false;
                    }

                    value = (T)deserialized;
                    return true;
                }
            }
            catch (Exception exception)
            {
                error = exception.GetType().Name + ": " + exception.Message;
                return false;
            }
        }
    }
}
