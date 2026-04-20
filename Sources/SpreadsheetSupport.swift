import Foundation

enum CSVTableSupport {
    static func parseRows(from rawValue: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var index = rawValue.startIndex

        func appendField() {
            currentRow.append(currentField)
            currentField = ""
        }

        func appendRow() {
            rows.append(currentRow)
            currentRow = []
        }

        while index < rawValue.endIndex {
            let character = rawValue[index]

            if isInsideQuotes {
                if character == "\"" {
                    let nextIndex = rawValue.index(after: index)
                    if nextIndex < rawValue.endIndex, rawValue[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        isInsideQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
            } else {
                switch character {
                case "\"":
                    isInsideQuotes = true
                case ",":
                    appendField()
                case "\n":
                    appendField()
                    appendRow()
                case "\r":
                    appendField()
                    appendRow()
                    let nextIndex = rawValue.index(after: index)
                    if nextIndex < rawValue.endIndex, rawValue[nextIndex] == "\n" {
                        index = nextIndex
                    }
                default:
                    currentField.append(character)
                }
            }

            index = rawValue.index(after: index)
        }

        appendField()
        if !currentRow.isEmpty || !rows.isEmpty {
            appendRow()
        }

        while let last = rows.last, last.count == 1, last[0].isEmpty {
            rows.removeLast()
        }

        return rows
    }

    static func table(from rawValue: String) -> MarkdownTable? {
        let rows = parseRows(from: rawValue)
        guard let headers = rows.first, !headers.isEmpty else {
            return nil
        }

        let expectedColumnCount = headers.count
        let bodyRows = rows.dropFirst().map { row in
            normalized(row, expectedCount: expectedColumnCount)
        }

        return MarkdownTable(
            headers: normalized(headers, expectedCount: expectedColumnCount),
            alignments: Array(repeating: .leading, count: expectedColumnCount),
            rows: bodyRows
        )
    }

    private static func normalized(_ row: [String], expectedCount: Int) -> [String] {
        let prefix = Array(row.prefix(expectedCount))
        if prefix.count == expectedCount {
            return prefix
        }
        return prefix + Array(repeating: "", count: expectedCount - prefix.count)
    }
}

enum OOXMLSpreadsheetBuilder {
    static func xlsxData(for table: MarkdownTable, sheetName: String = "Sheet1") throws -> Data {
        let normalizedSheetName = sanitizeSheetName(sheetName)
        let worksheetXML = worksheetXML(for: table)

        let entries = [
            ZipArchiveEntry(path: "[Content_Types].xml", data: Data(contentTypesXML.utf8)),
            ZipArchiveEntry(path: "_rels/.rels", data: Data(rootRelationshipsXML.utf8)),
            ZipArchiveEntry(path: "xl/workbook.xml", data: Data(workbookXML(sheetName: normalizedSheetName).utf8)),
            ZipArchiveEntry(path: "xl/_rels/workbook.xml.rels", data: Data(workbookRelationshipsXML.utf8)),
            ZipArchiveEntry(path: "xl/styles.xml", data: Data(stylesXML.utf8)),
            ZipArchiveEntry(path: "xl/worksheets/sheet1.xml", data: Data(worksheetXML.utf8))
        ]

        return try SimpleZipArchive.archive(entries: entries)
    }

    private static func worksheetXML(for table: MarkdownTable) -> String {
        let headerCells = table.headers.enumerated().map { index, value in
            inlineStringCell(reference: cellReference(column: index, row: 1), value: value)
        }.joined()

        let bodyRows = table.rows.enumerated().map { rowIndex, row in
            let rowNumber = rowIndex + 2
            let cellMarkup = row.enumerated().map { columnIndex, value in
                cellXML(reference: cellReference(column: columnIndex, row: rowNumber), value: value)
            }.joined()
            return "<row r=\"\(rowNumber)\">\(cellMarkup)</row>"
        }.joined()

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">\(headerCells)</row>
            \(bodyRows)
          </sheetData>
        </worksheet>
        """
    }

    private static func cellXML(reference: String, value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let number = Double(trimmed), !trimmed.isEmpty {
            return "<c r=\"\(reference)\"><v>\(numberString(number))</v></c>"
        }
        return inlineStringCell(reference: reference, value: value)
    }

    private static func inlineStringCell(reference: String, value: String) -> String {
        "<c r=\"\(reference)\" t=\"inlineStr\"><is><t>\(escapeXML(value))</t></is></c>"
    }

    private static func cellReference(column: Int, row: Int) -> String {
        "\(columnName(for: column))\(row)"
    }

    private static func columnName(for column: Int) -> String {
        var result = ""
        var value = column
        repeat {
            result = String(UnicodeScalar(65 + (value % 26))!) + result
            value = (value / 26) - 1
        } while value >= 0
        return result
    }

    private static func sanitizeSheetName(_ rawValue: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "[]:*?/\\")
        let cleaned = rawValue.unicodeScalars.map { invalidCharacters.contains($0) ? "-" : Character($0) }
        let trimmed = String(cleaned).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sheet1" : String(trimmed.prefix(31))
    }

    private static func numberString(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let contentTypesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    </Types>
    """

    private static let rootRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """

    private static func workbookXML(sheetName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="\(escapeXML(sheetName))" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """
    }

    private static let workbookRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="1"><font><sz val="11"/><name val="Aptos"/></font></fonts>
      <fills count="1"><fill><patternFill patternType="none"/></fill></fills>
      <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """
}

private struct ZipArchiveEntry {
    let path: String
    let data: Data
}

private enum SimpleZipArchive {
    static func archive(entries: [ZipArchiveEntry]) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            let entryData = entry.data
            let fileNameData = Data(entry.path.utf8)
            let crc = CRC32.checksum(for: entryData)
            let localHeaderOffset = UInt32(archive.count)
            offsets.append(localHeaderOffset)

            archive.append(littleEndian: UInt32(0x04034b50))
            archive.append(littleEndian: UInt16(20))
            archive.append(littleEndian: UInt16(0))
            archive.append(littleEndian: UInt16(0))
            archive.append(littleEndian: UInt16(0))
            archive.append(littleEndian: UInt16(0))
            archive.append(littleEndian: crc)
            archive.append(littleEndian: UInt32(entryData.count))
            archive.append(littleEndian: UInt32(entryData.count))
            archive.append(littleEndian: UInt16(fileNameData.count))
            archive.append(littleEndian: UInt16(0))
            archive.append(fileNameData)
            archive.append(entryData)
        }

        let centralDirectoryOffset = UInt32(archive.count)

        for (index, entry) in entries.enumerated() {
            let fileNameData = Data(entry.path.utf8)
            let crc = CRC32.checksum(for: entry.data)

            centralDirectory.append(littleEndian: UInt32(0x02014b50))
            centralDirectory.append(littleEndian: UInt16(20))
            centralDirectory.append(littleEndian: UInt16(20))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: crc)
            centralDirectory.append(littleEndian: UInt32(entry.data.count))
            centralDirectory.append(littleEndian: UInt32(entry.data.count))
            centralDirectory.append(littleEndian: UInt16(fileNameData.count))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt16(0))
            centralDirectory.append(littleEndian: UInt32(0))
            centralDirectory.append(littleEndian: offsets[index])
            centralDirectory.append(fileNameData)
        }

        archive.append(centralDirectory)
        archive.append(littleEndian: UInt32(0x06054b50))
        archive.append(littleEndian: UInt16(0))
        archive.append(littleEndian: UInt16(0))
        archive.append(littleEndian: UInt16(entries.count))
        archive.append(littleEndian: UInt16(entries.count))
        archive.append(littleEndian: UInt32(centralDirectory.count))
        archive.append(littleEndian: centralDirectoryOffset)
        archive.append(littleEndian: UInt16(0))
        return archive
    }
}

private enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { value in
            var crc = UInt32(value)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = 0xEDB88320 ^ (crc >> 1)
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()

    static func checksum(for data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(littleEndian value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { buffer in
            append(contentsOf: buffer.bindMemory(to: UInt8.self))
        }
    }
}
