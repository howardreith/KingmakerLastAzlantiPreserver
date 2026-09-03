using System;
using System.Collections.Generic;

namespace KingmakerLastAzlantiPreserver.Tests
{
    internal static class AssertEx
    {
        public static void True(bool value, string message = null)
        {
            if (!value) throw new InvalidOperationException(message ?? "Expected true.");
        }

        public static void False(bool value, string message = null)
        {
            if (value) throw new InvalidOperationException(message ?? "Expected false.");
        }

        public static void Equal<T>(T expected, T actual, string message = null)
        {
            if (!EqualityComparer<T>.Default.Equals(expected, actual))
            {
                throw new InvalidOperationException(message ?? "Expected <" + expected + ">, actual <" + actual + ">.");
            }
        }

        public static void SequenceEqual(byte[] expected, byte[] actual, string message = null)
        {
            if (expected == null || actual == null || expected.Length != actual.Length)
            {
                throw new InvalidOperationException(message ?? "Byte sequences differ in length.");
            }

            for (int index = 0; index < expected.Length; index++)
            {
                if (expected[index] != actual[index])
                {
                    throw new InvalidOperationException(message ?? "Byte sequences differ at index " + index + ".");
                }
            }
        }
    }
}
