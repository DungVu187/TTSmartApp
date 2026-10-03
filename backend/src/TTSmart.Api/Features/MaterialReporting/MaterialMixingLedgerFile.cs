using System.IO.Compression;
using System.Runtime.InteropServices;

namespace TTSmart.Api.Features.MaterialReporting;

/// <summary>
/// The ledger of a station on the disk of the API, so a restart or an IIS recycle does not add up
/// the history on the station database again. A cache: a file of another format, station or
/// database is ignored and rebuilt.
/// </summary>
internal static class MaterialMixingLedgerFile
{
    private const string Magic = "TTSMART-MIXING-LEDGER";
    private const int FormatVersion = 1;

    public static void Save(
        string path,
        int branchId,
        string databaseName,
        MaterialMixingLedger ledger,
        IReadOnlyList<(string Hash, string Name)> names)
    {
        var directory = Path.GetDirectoryName(path)!;
        Directory.CreateDirectory(directory);
        var temporary = Path.Combine(directory, $"{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            using (var zip = new GZipStream(file, CompressionLevel.Fastest))
            using (var writer = new BinaryWriter(zip))
            {
                writer.Write(Magic);
                writer.Write(FormatVersion);
                writer.Write(branchId);
                writer.Write(databaseName);
                writer.Write(ledger.HasMixingTables);
                writer.Write(ledger.BuiltAtUtc.Ticks);
                writer.Write(ledger.VerifiedAtUtc.Ticks);
                writer.Write(names.Count);
                foreach (var (hash, name) in names)
                {
                    writer.Write(hash);
                    writer.Write(name);
                }
                writer.Write(ledger.SealedChunks.Count);
                foreach (var chunk in ledger.SealedChunks)
                {
                    WriteChunk(writer, chunk);
                }
                WriteChunk(writer, ledger.Tail);
                writer.Write(ledger.TailFirstSeenUtc.Count);
                foreach (var (detailId, seenAt) in ledger.TailFirstSeenUtc)
                {
                    writer.Write(detailId);
                    writer.Write(seenAt.Ticks);
                }
                writer.Write(ledger.SealedSplitMixes.Count);
                foreach (var mixId in ledger.SealedSplitMixes)
                {
                    writer.Write(mixId);
                }
            }
            File.Move(temporary, path, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporary))
            {
                File.Delete(temporary);
            }
        }
    }

    /// <summary>The saved ledger, or null when there is none for this station and database.</summary>
    public static (MaterialMixingLedger Ledger, (string Hash, string Name)[] Names)? Load(
        string path,
        int branchId,
        string databaseName)
    {
        if (!File.Exists(path))
        {
            return null;
        }

        using var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        using var zip = new GZipStream(file, CompressionMode.Decompress);
        using var reader = new BinaryReader(zip);
        if (reader.ReadString() != Magic ||
            reader.ReadInt32() != FormatVersion ||
            reader.ReadInt32() != branchId ||
            !string.Equals(reader.ReadString(), databaseName, StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var hasMixingTables = reader.ReadBoolean();
        var builtAt = new DateTime(reader.ReadInt64(), DateTimeKind.Utc);
        var verifiedAt = new DateTime(reader.ReadInt64(), DateTimeKind.Utc);
        var names = new (string Hash, string Name)[reader.ReadInt32()];
        for (var index = 0; index < names.Length; index++)
        {
            names[index] = (reader.ReadString(), reader.ReadString());
        }
        var sealedChunks = new MaterialMixingLedgerChunk[reader.ReadInt32()];
        for (var index = 0; index < sealedChunks.Length; index++)
        {
            sealedChunks[index] = ReadChunk(reader, zip);
        }
        var tail = ReadChunk(reader, zip);
        var firstSeenCount = reader.ReadInt32();
        var firstSeen = new Dictionary<long, DateTime>(firstSeenCount);
        for (var index = 0; index < firstSeenCount; index++)
        {
            firstSeen[reader.ReadInt64()] = new DateTime(reader.ReadInt64(), DateTimeKind.Utc);
        }
        var splitCount = reader.ReadInt32();
        var split = new HashSet<long>(splitCount);
        for (var index = 0; index < splitCount; index++)
        {
            split.Add(reader.ReadInt64());
        }

        var ledger = new MaterialMixingLedger(
            hasMixingTables,
            names.Select(item => item.Name).ToArray(),
            sealedChunks,
            tail,
            firstSeen,
            builtAt,
            verifiedAt,
            split);
        return (ledger, names);
    }

    private static void WriteChunk(BinaryWriter writer, MaterialMixingLedgerChunk chunk)
    {
        writer.Write(chunk.DetailAfter);
        writer.Write(chunk.DetailUpTo);
        writer.Write(chunk.MixIds.Length);
        writer.Write(chunk.EntryCount);
        WriteArray(writer, chunk.MixIds);
        WriteArray(writer, chunk.Finish3Ticks);
        WriteArray(writer, chunk.Finish7Ticks);
        WriteArray(writer, chunk.MixEntryStart);
        WriteArray(writer, chunk.Slots);
        WriteArray(writer, chunk.NameIndexes);
        WriteArray(writer, chunk.Quantities);
    }

    private static MaterialMixingLedgerChunk ReadChunk(BinaryReader reader, Stream stream)
    {
        var after = reader.ReadInt64();
        var upTo = reader.ReadInt64();
        var mixes = reader.ReadInt32();
        var entries = reader.ReadInt32();
        if (mixes < 0 || entries < 0)
        {
            throw new InvalidDataException("Negative ledger chunk size.");
        }
        return new MaterialMixingLedgerChunk(
            after,
            upTo,
            ReadArray<long>(stream, mixes),
            ReadArray<long>(stream, mixes),
            ReadArray<long>(stream, mixes),
            ReadArray<int>(stream, mixes + 1),
            ReadArray<int>(stream, entries),
            ReadArray<int>(stream, entries),
            ReadArray<long>(stream, entries));
    }

    private static void WriteArray<T>(BinaryWriter writer, T[] values)
        where T : unmanaged =>
        writer.Write(MemoryMarshal.AsBytes(values.AsSpan()));

    private static T[] ReadArray<T>(Stream stream, int count)
        where T : unmanaged
    {
        var values = new T[count];
        stream.ReadExactly(MemoryMarshal.AsBytes(values.AsSpan()));
        return values;
    }
}
