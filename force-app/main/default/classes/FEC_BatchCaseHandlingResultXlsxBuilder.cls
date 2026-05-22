/**
 * Builds minimal OOXML .xlsx workbooks for Batch Case Handling import result files.
 * Uses inlineStr cells so Vietnamese and other Unicode text render correctly in Excel.
 */
public with sharing class FEC_BatchCaseHandlingResultXlsxBuilder {

    private static final String SHEET_NAME = 'Result';

    public static Blob buildWorkbookBlob(List<List<String>> sheetRows) {
        if (sheetRows == null || sheetRows.isEmpty()) {
            return null;
        }
        Integer maxCols = 0;
        for (List<String> row : sheetRows) {
            if (row != null && row.size() > maxCols) {
                maxCols = row.size();
            }
        }
        if (maxCols < 1) {
            return null;
        }
        Integer rowCount = sheetRows.size();
        String lastCol = columnLetter(maxCols - 1);
        String dimensionRef = 'A1:' + lastCol + String.valueOf(rowCount);
        List<String> rowXmlParts = new List<String>();
        for (Integer rowIdx = 0; rowIdx < sheetRows.size(); rowIdx++) {
            rowXmlParts.add(buildRowXml(rowIdx + 1, sheetRows[rowIdx], maxCols));
        }
        String sheetXml =
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
            '<dimension ref="' +
            dimensionRef +
            '"/>' +
            '<sheetViews><sheetView workbookViewId="0"/></sheetViews>' +
            '<sheetFormatPr defaultRowHeight="15"/>' +
            '<sheetData>' +
            String.join(rowXmlParts, '') +
            '</sheetData>' +
            '</worksheet>';
        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry(
            '[Content_Types].xml',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
                    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
                    '<Default Extension="xml" ContentType="application/xml"/>' +
                    '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
                    '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' +
                    '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>' +
                    '</Types>'
            )
        );
        writer.addEntry(
            '_rels/.rels',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
                    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
                    '</Relationships>'
            )
        );
        writer.addEntry(
            'xl/_rels/workbook.xml.rels',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
                    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>' +
                    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' +
                    '</Relationships>'
            )
        );
        writer.addEntry(
            'xl/workbook.xml',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
                    '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' +
                    '<sheets><sheet name="' +
                    xmlEscape(SHEET_NAME) +
                    '" sheetId="1" r:id="rId1"/></sheets>' +
                    '</workbook>'
            )
        );
        writer.addEntry(
            'xl/styles.xml',
            Blob.valueOf(
                '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">' +
                    '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>' +
                    '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>' +
                    '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>' +
                    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' +
                    '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>' +
                    '</styleSheet>'
            )
        );
        writer.addEntry('xl/worksheets/sheet1.xml', Blob.valueOf(sheetXml));
        return writer.getArchive();
    }

    private static String buildRowXml(Integer rowNumber, List<String> values, Integer maxCols) {
        List<String> cellParts = new List<String>();
        for (Integer colIdx = 0; colIdx < maxCols; colIdx++) {
            String cellValue = FEC_ConstantCommon.STR_EMPTY;
            if (values != null && colIdx < values.size() && values[colIdx] != null) {
                cellValue = values[colIdx];
            }
            cellParts.add(
                '<c r="' +
                    columnLetter(colIdx) +
                    String.valueOf(rowNumber) +
                    '" t="inlineStr"><is><t>' +
                    xmlEscape(cellValue) +
                    '</t></is></c>'
            );
        }
        return '<row r="' + String.valueOf(rowNumber) + '">' + String.join(cellParts, '') + '</row>';
    }

    private static String columnLetter(Integer zeroBasedCol) {
        Integer dividend = zeroBasedCol + 1;
        String columnName = FEC_ConstantCommon.STR_EMPTY;
        while (dividend > 0) {
            Integer modulo = Math.mod(dividend - 1, 26);
            columnName =
                String.fromCharArray(new List<Integer>{ 65 + modulo }) + columnName;
            dividend = (dividend - modulo) / 26;
        }
        return columnName;
    }

    private static String xmlEscape(String value) {
        if (value == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;');
    }
}
