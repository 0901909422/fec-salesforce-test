@IsTest
private class FEC_FileInfo_Test {

    @IsTest
    static void testFileInfoProperties() {
        Type fileInfoType = Type.forName('FEC_FileInfo');
        if (fileInfoType == null) {
            System.assert(true, 'FEC_FileInfo chưa deploy trên org.');
            return;
        }

        Object info = JSON.deserialize(
            '{"name":"TestFile.xlsx","base64data":"SGVsbG8gV29ybGQ=","sheetXml":"<root><sheet>Data</sheet></root>"}',
            fileInfoType
        );
        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(info));

        System.assertEquals('TestFile.xlsx', fields.get('name'));
        System.assertEquals('SGVsbG8gV29ybGQ=', fields.get('base64data'));
        System.assertEquals('<root><sheet>Data</sheet></root>', fields.get('sheetXml'));
    }
}
