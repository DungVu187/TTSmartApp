using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Xml;

namespace TTSmart.Api.Features.OrderStatistics;

internal static class OrderStatisticsXlsxWriter
{
    private const string MainNamespace =
        "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private const string RelationshipNamespace =
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
    private const string PackageRelationshipNamespace =
        "http://schemas.openxmlformats.org/package/2006/relationships";
    private const string ContentTypeNamespace =
        "http://schemas.openxmlformats.org/package/2006/content-types";
    private const string WorkbookContentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml";
    private const string WorksheetContentType =
        "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml";
    private const string DocumentRelationshipType =
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument";
    private const string WorksheetRelationshipType =
        "http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet";
    private static readonly TimeSpan VietnamOffset = TimeSpan.FromHours(7);

    public static byte[] Create(OrderStatisticsExportDataset data)
    {
        var worksheets = BuildWorksheets(data);
        using var stream = new MemoryStream();
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            WriteEntry(
                archive,
                "[Content_Types].xml",
                writer => WriteContentTypes(writer, worksheets.Count));
            WriteEntry(archive, "_rels/.rels", WritePackageRelationships);
            WriteEntry(
                archive,
                "xl/workbook.xml",
                writer => WriteWorkbook(writer, worksheets));
            WriteEntry(
                archive,
                "xl/_rels/workbook.xml.rels",
                writer => WriteWorkbookRelationships(writer, worksheets.Count));
            for (var index = 0; index < worksheets.Count; index++)
            {
                var worksheet = worksheets[index];
                WriteEntry(
                    archive,
                    $"xl/worksheets/sheet{index + 1}.xml",
                    writer => WriteWorksheet(writer, worksheet));
            }
        }
        return stream.ToArray();
    }

    private static void WriteEntry(
        ZipArchive archive,
        string name,
        Action<XmlWriter> write)
    {
        var entry = archive.CreateEntry(name, CompressionLevel.Fastest);
        using var stream = entry.Open();
        using var writer = XmlWriter.Create(
            stream,
            new XmlWriterSettings
            {
                Encoding = new UTF8Encoding(false),
                OmitXmlDeclaration = false,
                Indent = false
            });
        write(writer);
    }

    private static void WriteContentTypes(XmlWriter writer, int worksheetCount)
    {
        writer.WriteStartElement("Types", ContentTypeNamespace);
        WriteDefaultContentType(writer, "rels", "application/vnd.openxmlformats-package.relationships+xml");
        WriteDefaultContentType(writer, "xml", "application/xml");
        WriteOverrideContentType(writer, "/xl/workbook.xml", WorkbookContentType);
        for (var index = 1; index <= worksheetCount; index++)
        {
            WriteOverrideContentType(
                writer,
                $"/xl/worksheets/sheet{index}.xml",
                WorksheetContentType);
        }
        writer.WriteEndElement();
    }

    private static void WriteDefaultContentType(
        XmlWriter writer,
        string extension,
        string contentType)
    {
        writer.WriteStartElement("Default");
        writer.WriteAttributeString("Extension", extension);
        writer.WriteAttributeString("ContentType", contentType);
        writer.WriteEndElement();
    }

    private static void WriteOverrideContentType(
        XmlWriter writer,
        string partName,
        string contentType)
    {
        writer.WriteStartElement("Override");
        writer.WriteAttributeString("PartName", partName);
        writer.WriteAttributeString("ContentType", contentType);
        writer.WriteEndElement();
    }

    private static void WritePackageRelationships(XmlWriter writer)
    {
        writer.WriteStartElement("Relationships", PackageRelationshipNamespace);
        WriteRelationship(
            writer,
            "rId1",
            DocumentRelationshipType,
            "xl/workbook.xml");
        writer.WriteEndElement();
    }

    private static void WriteWorkbook(
        XmlWriter writer,
        IReadOnlyList<WorksheetDefinition> worksheets)
    {
        writer.WriteStartElement("workbook", MainNamespace);
        writer.WriteAttributeString("xmlns", "r", null, RelationshipNamespace);
        writer.WriteStartElement("sheets");
        for (var index = 0; index < worksheets.Count; index++)
        {
            writer.WriteStartElement("sheet");
            writer.WriteAttributeString("name", worksheets[index].Name);
            writer.WriteAttributeString("sheetId", (index + 1).ToString(CultureInfo.InvariantCulture));
            writer.WriteAttributeString(
                "r",
                "id",
                RelationshipNamespace,
                $"rId{index + 1}");
            writer.WriteEndElement();
        }
        writer.WriteEndElement();
        writer.WriteEndElement();
    }

    private static void WriteWorkbookRelationships(XmlWriter writer, int worksheetCount)
    {
        writer.WriteStartElement("Relationships", PackageRelationshipNamespace);
        for (var index = 1; index <= worksheetCount; index++)
        {
            WriteRelationship(
                writer,
                $"rId{index}",
                WorksheetRelationshipType,
                $"worksheets/sheet{index}.xml");
        }
        writer.WriteEndElement();
    }

    private static void WriteRelationship(
        XmlWriter writer,
        string id,
        string type,
        string target)
    {
        writer.WriteStartElement("Relationship");
        writer.WriteAttributeString("Id", id);
        writer.WriteAttributeString("Type", type);
        writer.WriteAttributeString("Target", target);
        writer.WriteEndElement();
    }

    private static IReadOnlyList<WorksheetDefinition> BuildWorksheets(
        OrderStatisticsExportDataset data)
    {
        var worksheets = new List<WorksheetDefinition>();
        var usedNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        for (var index = 0; index < data.Layouts.Count; index++)
        {
            var layout = data.Layouts[index];
            var name = data.Layouts.Count == 1
                ? "ChiTiet"
                : CreateUniqueSheetName($"ChiTiet_{layout.LayoutKey}", usedNames);
            usedNames.Add(name);
            worksheets.Add(new WorksheetDefinition(
                name,
                BuildDetailRows(layout),
                FreezeRows: 2,
                AutoFilterRow: 2));
        }

        worksheets.Add(new WorksheetDefinition(
            CreateUniqueSheetName("TongHop", usedNames),
            BuildSummaryRows(data),
            FreezeRows: 5,
            AutoFilterRow: null));
        return worksheets;
    }

    private static IReadOnlyList<IReadOnlyList<XlsxCell>> BuildDetailRows(
        OrderStatisticsExportLayout layout)
    {
        var rows = new List<IReadOnlyList<XlsxCell>>
        {
            new XlsxCell[] { Text("LayoutKey"), Text(layout.LayoutKey) },
            BuildDetailHeader(layout.MaterialColumns)
        };
        rows.AddRange(layout.Items.Select(item => BuildDetailRow(item, layout.MaterialColumns)));
        return rows;
    }

    private static IReadOnlyList<XlsxCell> BuildDetailHeader(
        IReadOnlyList<OrderStatisticsExportMaterialColumn> materialColumns)
    {
        var cells = new List<XlsxCell>
        {
            Text("STT"),
            Text("NGÀY"),
            Text("BẮT ĐẦU"),
            Text("KẾT THÚC"),
            Text("TÊN KHÁCH HÀNG"),
            Text("TÊN DỰ ÁN"),
            Text("TÊN HẠNG MỤC"),
            Text("TÊN ĐỊA ĐIỂM"),
            Text("XE"),
            Text("TÊN LÁI XE"),
            Text("MÁC BÊ TÔNG"),
            Text("ĐỘ SỤT"),
            Text("NV KINH DOANH"),
            Text("TÊN NHÂN VIÊN"),
            Text("THỂ TÍCH ĐẶT"),
            Text("THỂ TÍCH TRỘN")
        };
        foreach (var column in materialColumns)
        {
            cells.Add(Text(column.DesignLabel));
            cells.Add(Text(column.TLabel));
            cells.Add(Text(column.ActualLabel));
            cells.Add(Text(column.VarianceLabel));
        }
        return cells;
    }

    private static IReadOnlyList<XlsxCell> BuildDetailRow(
        OrderStatisticsItemResponse item,
        IReadOnlyList<OrderStatisticsExportMaterialColumn> materialColumns)
    {
        var cells = new List<XlsxCell>
        {
            Number(item.RowNumber),
            Text(item.MixingDate?.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)),
            Text(ToVietnamTime(item.StartedAt)),
            Text(ToVietnamTime(item.FinishedAt)),
            Text(item.CustomerName),
            Text(item.ProjectName),
            Text(item.WorkItemName),
            Text(item.LocationName),
            Text(item.VehiclePlate),
            Text(item.DriverName),
            Text(item.ConcreteGradeName),
            Text(item.Slump),
            Text(item.SalesEmployeeName),
            Text(item.EmployeeName),
            Number(item.RequestedVolume),
            Number(item.MixedVolume)
        };
        var materials = item.Materials
            .GroupBy(material => material.SlotNumber)
            .ToDictionary(group => group.Key, group => group.First());
        foreach (var column in materialColumns)
        {
            materials.TryGetValue(column.SlotNumber, out var material);
            cells.Add(Number(material?.DesignQuantity ?? 0));
            cells.Add(Number(material?.TQuantity ?? 0));
            cells.Add(Number(material?.ActualQuantity ?? 0));
            cells.Add(Number(material?.Variance ?? 0));
        }
        return cells;
    }

    private static IReadOnlyList<IReadOnlyList<XlsxCell>> BuildSummaryRows(
        OrderStatisticsExportDataset data)
    {
        var rows = new List<IReadOnlyList<XlsxCell>>
        {
            new XlsxCell[] { Text("TỔNG HỢP THỐNG KÊ ĐƠN HÀNG") },
            Array.Empty<XlsxCell>(),
            new XlsxCell[]
            {
                Text("Tổng vật liệu thực tế"),
                Number(data.TotalMaterialQuantity),
                Text("Tổng khối lượng bê tông"),
                Number(data.TotalConcreteVolume)
            },
            Array.Empty<XlsxCell>(),
            data.MaterialSummary.Headers.Select(Text).ToArray()
        };
        rows.AddRange(data.MaterialSummary.Rows.Select(row =>
            (IReadOnlyList<XlsxCell>)row
                .Select(value => value.Number.HasValue
                    ? Number(value.Number.Value)
                    : Text(value.Text))
                .ToArray()));
        return rows;
    }

    private static string? ToVietnamTime(DateTimeOffset? value) =>
        value?.ToOffset(VietnamOffset).ToString("HH:mm:ss", CultureInfo.InvariantCulture);

    private static string CreateUniqueSheetName(
        string candidate,
        ISet<string> usedNames)
    {
        var invalidCharacters = new HashSet<char>(['[', ']', ':', '*', '?', '/', '\\']);
        var sanitized = new string(candidate
            .Select(character => invalidCharacters.Contains(character) ? '_' : character)
            .ToArray())
            .Trim('\'');
        if (string.IsNullOrWhiteSpace(sanitized))
        {
            sanitized = "Sheet";
        }
        sanitized = sanitized[..Math.Min(31, sanitized.Length)];
        var name = sanitized;
        var suffix = 2;
        while (usedNames.Contains(name))
        {
            var suffixText = $"_{suffix++}";
            name = sanitized[..Math.Min(31 - suffixText.Length, sanitized.Length)] + suffixText;
        }
        return name;
    }

    private static void WriteWorksheet(
        XmlWriter writer,
        WorksheetDefinition worksheet)
    {
        var rowCount = Math.Max(1, worksheet.Rows.Count);
        var columnCount = Math.Max(
            1,
            worksheet.Rows.Count == 0 ? 0 : worksheet.Rows.Max(row => row.Count));
        writer.WriteStartElement("worksheet", MainNamespace);
        writer.WriteStartElement("dimension");
        writer.WriteAttributeString(
            "ref",
            $"A1:{CellReference(columnCount, rowCount)}");
        writer.WriteEndElement();
        writer.WriteStartElement("sheetViews");
        writer.WriteStartElement("sheetView");
        writer.WriteAttributeString("workbookViewId", "0");
        if (worksheet.FreezeRows > 0)
        {
            writer.WriteStartElement("pane");
            writer.WriteAttributeString(
                "ySplit",
                worksheet.FreezeRows.ToString(CultureInfo.InvariantCulture));
            writer.WriteAttributeString(
                "topLeftCell",
                $"A{worksheet.FreezeRows + 1}");
            writer.WriteAttributeString("activePane", "bottomLeft");
            writer.WriteAttributeString("state", "frozen");
            writer.WriteEndElement();
        }
        writer.WriteEndElement();
        writer.WriteEndElement();
        writer.WriteStartElement("sheetData");
        for (var rowIndex = 0; rowIndex < worksheet.Rows.Count; rowIndex++)
        {
            writer.WriteStartElement("row");
            writer.WriteAttributeString(
                "r",
                (rowIndex + 1).ToString(CultureInfo.InvariantCulture));
            var row = worksheet.Rows[rowIndex];
            for (var columnIndex = 0; columnIndex < row.Count; columnIndex++)
            {
                WriteCell(writer, rowIndex + 1, columnIndex + 1, row[columnIndex]);
            }
            writer.WriteEndElement();
        }
        writer.WriteEndElement();
        if (worksheet.AutoFilterRow.HasValue)
        {
            writer.WriteStartElement("autoFilter");
            writer.WriteAttributeString(
                "ref",
                $"A{worksheet.AutoFilterRow}:{CellReference(columnCount, rowCount)}");
            writer.WriteEndElement();
        }
        writer.WriteEndElement();
    }

    private static void WriteCell(
        XmlWriter writer,
        int rowNumber,
        int columnNumber,
        XlsxCell cell)
    {
        writer.WriteStartElement("c");
        writer.WriteAttributeString("r", CellReference(columnNumber, rowNumber));
        if (cell.Number.HasValue)
        {
            writer.WriteStartElement("v");
            writer.WriteString(cell.Number.Value.ToString(CultureInfo.InvariantCulture));
            writer.WriteEndElement();
        }
        else
        {
            writer.WriteAttributeString("t", "inlineStr");
            writer.WriteStartElement("is");
            writer.WriteStartElement("t");
            writer.WriteString(cell.Text ?? string.Empty);
            writer.WriteEndElement();
            writer.WriteEndElement();
        }
        writer.WriteEndElement();
    }

    private static string CellReference(int columnNumber, int rowNumber)
    {
        var columnName = new StringBuilder();
        var value = columnNumber;
        while (value > 0)
        {
            value--;
            columnName.Insert(0, (char)('A' + value % 26));
            value /= 26;
        }
        return columnName + rowNumber.ToString(CultureInfo.InvariantCulture);
    }

    private static XlsxCell Text(string? value) =>
        new(value ?? string.Empty, null);

    private static XlsxCell Number(decimal value) =>
        new(null, value);

    private readonly record struct XlsxCell(string? Text, decimal? Number);

    private sealed record WorksheetDefinition(
        string Name,
        IReadOnlyList<IReadOnlyList<XlsxCell>> Rows,
        int FreezeRows,
        int? AutoFilterRow);
}
