using System;

namespace KingmakerLastAzlantiPreserver.Integration
{
    public sealed class ScopedControlElevation
    {
        private readonly Func<object, bool> readEnabled;
        private readonly Action<object, bool> writeEnabled;
        private object owner;
        private object first;
        private object second;
        private bool firstVanillaState;
        private bool secondVanillaState;
        private bool elevated;

        public ScopedControlElevation(Func<object, bool> readEnabled, Action<object, bool> writeEnabled)
        {
            this.readEnabled = readEnabled ?? throw new ArgumentNullException(nameof(readEnabled));
            this.writeEnabled = writeEnabled ?? throw new ArgumentNullException(nameof(writeEnabled));
        }

        public bool IsElevated => elevated;
        public object Owner => owner;

        public void ObserveAfterVanilla(object newOwner, object firstControl, object secondControl)
        {
            if (newOwner == null) throw new ArgumentNullException(nameof(newOwner));
            if (firstControl == null) throw new ArgumentNullException(nameof(firstControl));
            if (secondControl == null) throw new ArgumentNullException(nameof(secondControl));
            if (owner != null && !ReferenceEquals(owner, newOwner)) Restore();
            owner = newOwner;
            first = firstControl;
            second = secondControl;
            firstVanillaState = readEnabled(firstControl);
            secondVanillaState = readEnabled(secondControl);
            elevated = false;
        }

        public void Apply(bool shouldElevate)
        {
            if (owner == null) return;
            if (shouldElevate)
            {
                if (!elevated)
                {
                    firstVanillaState = readEnabled(first);
                    secondVanillaState = readEnabled(second);
                }

                elevated = true;
                try
                {
                    writeEnabled(first, true);
                    writeEnabled(second, true);
                }
                catch (Exception elevationException)
                {
                    try
                    {
                        Restore();
                    }
                    catch (Exception restoreException)
                    {
                        throw new AggregateException(
                            "Control elevation failed and its baseline could not be fully restored.",
                            elevationException,
                            restoreException);
                    }

                    throw;
                }

                return;
            }

            Restore();
        }

        public void Detach(object expectedOwner)
        {
            if (expectedOwner != null && !ReferenceEquals(owner, expectedOwner)) return;
            try
            {
                Restore();
            }
            finally
            {
                owner = null;
                first = null;
                second = null;
            }
        }

        private void Restore()
        {
            if (!elevated) return;
            Exception firstFailure = null;
            try
            {
                writeEnabled(first, firstVanillaState);
            }
            catch (Exception exception)
            {
                firstFailure = exception;
            }

            Exception secondFailure = null;
            try
            {
                writeEnabled(second, secondVanillaState);
            }
            catch (Exception exception)
            {
                secondFailure = exception;
            }

            elevated = false;
            if (firstFailure != null && secondFailure != null)
            {
                throw new AggregateException("Both feature-owned controls failed baseline restoration.", firstFailure, secondFailure);
            }
            if (firstFailure != null) throw firstFailure;
            if (secondFailure != null) throw secondFailure;
        }
    }
}
