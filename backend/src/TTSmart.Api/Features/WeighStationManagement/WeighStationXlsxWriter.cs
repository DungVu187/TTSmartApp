using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Xml;

namespace TTSmart.Api.Features.WeighStationManagement;

internal static class WeighStationXlsxWriter
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

    public static byte[] CreateDetail(WeighStationResponse response)
    {
        var rows = new List<IReadOnlyList<Cell>>
        {
            BuildDetailHeader(response.CanViewMaterialValue)
        };
        rows.AddRange(response.Items.Select(item => BuildDetailRow(
            item,
            response.CanViewMaterialValue)));
        return CreateWorkbook("Chi tiết cân", rows);
    }

    public static byte[] CreateSummary(WeighStationSummaryResponse response)
    {
        var rows = new List<IReadOnlyList<Cell>>
        {
            new Cell[] { Text("Tổng số loại hàng"), Number(response.TotalCount) },
            new Cell[] { Text("Tổng khối lượng (kg)"), Number(response.TotalGoodsWeightKg) },
            new Cell[]
            {
                Text("Tổng khối lượng quy đổi"),
                Text(FormatConvertedQuantities(response.TotalConvertedQuantities))
            }
        };
        rows.Add(new Cell[]
        {
            Text("Loại hàng nhiều nhất"),
            Text(response.TopGoods?.GoodsName),
            Number(response.TopGoods?.GoodsWeightKg)
        });
        if (response.CanViewMaterialValue)
        {
            rows.Add(new Cell[]
            {
                Text("Tổng giá trị (VNĐ)"),
                Number(response.TotalMaterialValueVnd)
            });
        }
        rows.Add(Array.Empty<Cell>());
        rows.Add(BuildSummaryHeader(response.CanViewMaterialValue));
        rows.AddRange(response.Items.Select(item => BuildSummaryRow(
            item,
            response.CanViewMaterialValue)));
        return CreateWorkbook("Tổng hợp", rows);
    }

    private static IReadOnlyList<Cell> BuildDetailHeader(bool includeMaterialValue)
    {
        var cells = new List<Cell>
        {
            Text("STT"),
            Text("Số phiếu"),
            Text("Mã phiếu"),
            Text("Ngày cân"),
            Text("Biển xe"),
            Text("Lái xe"),
            Text("Số niêm chì"),
            Text("KL cân vào (kg)"),
            Text("KL cân ra (kg)"),
            Text("Khối lượng hàng (kg)"),
            Text("Khối lượng quy đổi"),
            Text("Đơn vị quy đổi")
        };
        if (includeMaterialValue)
        {
            cells.Add(Text("Giá trị (VNĐ)"));
        }
        cells.AddRange([
            Text("Đơn vị"),
            Text("Loại hàng"),
            Text("Kiểu cân"),
            Text("Người cân lần 1"),
            Text("Người cân lần 2"),
            Text("T.Gian cân vào"),
            Text("T.Gian cân ra")
        ]);
        return cells;
    }

    private static IReadOnlyList<Cell> BuildDetailRow(
        WeighStationItemResponse item,
        bool includeMaterialValue)
    {
        var cells = new List<Cell>
        {
            Number(item.Stt),
            Number(item.TicketNumber),
            Text(item.TicketCode),
            Text(FormatDateTime(item.WeighingAt)),
            Text(item.VehiclePlate),
            Text(item.DriverName),
            Text(item.SealNumber),
            Number(item.InboundWeightKg),
            Number(item.OutboundWeightKg),
            Number(item.GoodsWeightKg),
            item.ConversionMessage is null
                ? Number(item.ConvertedQuantity)
                : Text(item.ConversionMessage),
            Text(item.ConvertedUnit)
        };
        if (includeMaterialValue)
        {
            cells.Add(Number(item.MaterialValueVnd));
        }
        cells.AddRange([
            Text(item.UnitName),
            Text(item.GoodsName),
            Text(item.WeighingType),
            Text(item.FirstOperatorName),
            Text(item.SecondOperatorName),
            Text(FormatDateTime(item.WeighedInAt)),
            Text(FormatDateTime(item.WeighedOutAt))
        ]);
        return cells;
    }

    private static IReadOnlyList<Cell> BuildSummaryHeader(bool includeMaterialValue)
    {
        var cells = new List<Cell>
        {
            Text("STT"),
            Text("Tên hàng"),
            Text("Khối lượng (kg)"),
            Text("Quy đổi")
        };
        if (includeMaterialValue)
        {
            cells.Add(Text("Giá trị (VNĐ)"));
        }
        return cells;
    }

    private static IReadOnlyList<Cell> BuildSummaryRow(
        WeighStationSummaryItemResponse item,
        bool includeMaterialValue)
    {
        var cells = new List<Cell>
        {
            Number(item.Stt),
            Text(item.GoodsName),
            Number(item.GoodsWeightKg),
            Text(FormatConvertedQuantities(item.ConvertedQuantities, item.ConversionMessage))
        };
        if (includeMaterialValue)
        {
            cells.Add(Number(item.MaterialValueVnd));
        }
        return cells;
    }

    private static byte[] CreateWorkbook(
        string sheetName,
        IReadOnlyList<IReadOnlyList<Cell>> rows)
    {
        using var stream = new MemoryStream();
        using (var archive = new ZipArchive(stream, ZipArchiveMode.Create, leaveOpen: true))
        {
            WriteEntry(archive, "[Content_Types].xml", WriteContentTypes);
            WriteEntry(archive, "_rels/.rels", WritePackageRelationships);
            WriteEntry(archive, "xl/workbook.xml", writer => WriteWorkbook(writer, sheetName));
            WriteEntry(archive, "xl/_rels/workbook.xml.rels", WriteWorkbookRelationships);
            WriteEntry(archive, "xl/worksheets/sheet1.xml", writer => WriteWorksheet(writer, rows));
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
        using var writer = XmlWriter.Create(stream, new XmlWriterSettings
        {
            Encoding = new UTF8Encoding(false),
            OmitXmlDeclaration = false,
            Indent = false
        });
        write(writer);
    }

    private static void WriteContentTypes(XmlWriter writer)
    {
        writer.WriteStartElement("Types", ContentTypeNamespace);
        WriteContentType(writer, "Default", "Extension", "rels",
            "application/vnd.openxmlformats-package.relationships+xml");
        WriteContentType(writer, "Default", "Extension", "xml", "application/xml");
        WriteContentType(writer, "Override", "PartName", "/xl/workbook.xml", WorkbookContentType);
        WriteContentType(writer, "Override", "PartName", "/xl/worksheets/sheet1.xml", WorksheetContentType);
        writer.WriteEndElement();
    }

    private static void WriteContentType(
        XmlWriter writer,
        string element,
        string keyName,
        string keyValue,
        string contentType)
    {
        writer.WriteStartElement(element);
        writer.WriteAttributeString(keyName, keyValue);
        writer.WriteAttributeString("ContentType", contentType);
        writer.WriteEndElement();
    }

    private static void WritePackageRelationships(XmlWriter writer)
    {
        writer.WriteStartElement("Relationships", PackageRelationshipNamespace);
        WriteRelationship(writer, "rId1", DocumentRelationshipType, "xl/workbook.xml");
        writer.WriteEndElement();
    }

    private static void WriteWorkbook(XmlWriter writer, string sheetName)
    {
        writer.WriteStartElement("workbook", MainNamespace);
        writer.WriteAttributeString("xmlns", "r", null, RelationshipNamespace);
        writer.WriteStartElement("sheets");
        writer.WriteStartElement("sheet");
        writer.WriteAttributeString("name", sheetName);
        writer.WriteAttributeString("sheetId", "1");
        writer.WriteAttributeString("r", "id", RelationshipNamespace, "rId1");
        writer.WriteEndElement();
        writer.WriteEndElement();
        writer.WriteEndElement();
    }

    private static void WriteWorkbookRelationships(XmlWriter writer)
    {
        writer.WriteStartElement("Relationships", PackageRelationshipNamespace);
        WriteRelationship(writer, "rId1", WorksheetRelationshipType, "worksheets/sheet1.xml");
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

    private static void WriteWorksheet(
        XmlWriter writer,
        IReadOnlyList<IReadOnlyList<Cell>> rows)
    {
        writer.WriteStartElement("worksheet", MainNamespace);
        writer.WriteStartElement("sheetData");
        for (var rowIndex = 0; rowIndex < rows.Count; rowIndex++)
        {
            writer.WriteStartElement("row");
            writer.WriteAttributeString("r", (rowIndex + 1).ToString(CultureInfo.InvariantCulture));
            for (var columnIndex = 0; columnIndex < rows[rowIndex].Count; columnIndex++)
            {
                WriteCell(writer, rows[rowIndex][columnIndex], rowIndex + 1, columnIndex + 1);
            }
            writer.WriteEndElement();
        }
        writer.WriteEndElement();
        writer.WriteEndElement();
    }

    private static void WriteCell(
        XmlWriter writer,
        Cell cell,
        int rowNumber,
        int columnNumber)
    {
        writer.WriteStartElement("c");
        writer.WriteAttributeString("r", $"{GetColumnName(columnNumber)}{rowNumber}");
        if (cell.IsNumber && cell.Value is not null)
        {
            writer.WriteElementString("v", cell.Value);
        }
        else
        {
            writer.WriteAttributeString("t", "inlineStr");
            writer.WriteStartElement("is");
            writer.WriteStartElement("t");
            writer.WriteAttributeString("xml", "space", null, "preserve");
            writer.WriteString(RemoveInvalidXmlCharacters(cell.Value ?? string.Empty));
            writer.WriteEndElement();
            writer.WriteEndElement();
        }
        writer.WriteEndElement();
    }

    private static string GetColumnName(int columnNumber)
    {
        var builder = new StringBuilder();
        var value = columnNumber;
        while (value > 0)
        {
            value--;
            builder.Insert(0, (char)('A' + value % 26));
            value /= 26;
        }
        return builder.ToString();
    }

    private static string? FormatDateTime(DateTimeOffset? value) =>
        value?.ToOffset(VietnamOffset).ToString("dd-MM-yyyy HH:mm", CultureInfo.InvariantCulture);

    private static string FormatConvertedQuantities(
        IReadOnlyList<WeighStationConvertedQuantityResponse> values) =>
        string.Join("; ", values.Select(value =>
            $"{value.Quantity.ToString("0.###", CultureInfo.InvariantCulture)} {value.Unit}"));

    private static string FormatConvertedQuantities(
        IReadOnlyList<WeighStationConvertedQuantityResponse> values,
        string? conversionMessage)
    {
        var quantities = FormatConvertedQuantities(values);
        if (conversionMessage is null)
        {
            return quantities;
        }
        return string.IsNullOrEmpty(quantities)
            ? conversionMessage
            : $"{quantities}; {conversionMessage}";
    }

    private static string RemoveInvalidXmlCharacters(string value) =>
        string.Concat(value.Where(XmlConvert.IsXmlChar));

    private static Cell Text(string? value) => new(value, false);

    private static Cell Number(decimal? value) =>
        new(value?.ToString(CultureInfo.InvariantCulture), true);

    private static Cell Number(int? value) =>
        new(value?.ToString(CultureInfo.InvariantCulture), true);

    private sealed record Cell(string? Value, bool IsNumber);
}
