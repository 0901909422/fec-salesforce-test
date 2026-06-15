@IsTest
private class FEC_MyCaseBlobUtil_Test {

    private static final String UPLOAD_ID_MARKER = '<ID>UploadDocument</ID>';
    private static final String VALUE_OPEN = '<Value>';
    private static final String VALUE_CLOSE = '</Value>';

    private static String buildXmlWithUpload(String base64Content) {
        return '<root>' + UPLOAD_ID_MARKER + VALUE_OPEN + base64Content + VALUE_CLOSE + '</root>';
    }

    // ─── blobToAsciiString ────────────────────────────────────────────────────

    @IsTest
    static void testBlobToAsciiString_Null() {
        System.assertEquals(null, FEC_MyCaseBlobUtil.blobToAsciiString(null));
    }

    @IsTest
    static void testBlobToAsciiString_Empty() {
        Blob emptyBlob = Blob.valueOf('');
        // size == 0 → null
        System.assertEquals(null, FEC_MyCaseBlobUtil.blobToAsciiString(emptyBlob));
    }

    @IsTest
    static void testBlobToAsciiString_ValidString() {
        String input = '<root><data>hello</data></root>';
        System.assertEquals(input, FEC_MyCaseBlobUtil.blobToAsciiString(Blob.valueOf(input)));
    }

    // ─── needsUploadDocumentSlice ─────────────────────────────────────────────

    @IsTest
    static void testNeedsUploadDocumentSlice_Null() {
        System.assertEquals(false, FEC_MyCaseBlobUtil.needsUploadDocumentSlice(null));
    }

    @IsTest
    static void testNeedsUploadDocumentSlice_ShortNoMarker() {
        System.assertEquals(false, FEC_MyCaseBlobUtil.needsUploadDocumentSlice('<root></root>'));
    }

    @IsTest
    static void testNeedsUploadDocumentSlice_ShortWithMarker() {
        // Below threshold → false even though marker exists
        String xml = buildXmlWithUpload('SGVsbG8=');
        System.assertEquals(false, FEC_MyCaseBlobUtil.needsUploadDocumentSlice(xml));
    }

    @IsTest
    static void testNeedsUploadDocumentSlice_LargeNoMarker() {
        FEC_MyCaseBlobUtil.MAX_DIRECT_BODY_BYTES = 10;
        String xml = '<root><data>no upload marker here</data></root>';
        System.assertEquals(false, FEC_MyCaseBlobUtil.needsUploadDocumentSlice(xml));
    }

    @IsTest
    static void testNeedsUploadDocumentSlice_LargeWithMarker() {
        FEC_MyCaseBlobUtil.MAX_DIRECT_BODY_BYTES = 10;
        String xml = buildXmlWithUpload('SGVsbG9Xb3JsZA==');
        System.assertEquals(true, FEC_MyCaseBlobUtil.needsUploadDocumentSlice(xml));
    }

    // ─── needsUploadDocumentSliceForParse ────────────────────────────────────

    @IsTest
    static void testNeedsUploadDocumentSliceForParse_False() {
        System.assertEquals(false, FEC_MyCaseBlobUtil.needsUploadDocumentSliceForParse('<root></root>'));
    }

    @IsTest
    static void testNeedsUploadDocumentSliceForParse_True() {
        FEC_MyCaseBlobUtil.MAX_DIRECT_BODY_BYTES = 10;
        String xml = buildXmlWithUpload('SGVsbG9Xb3JsZA==');
        System.assertEquals(true, FEC_MyCaseBlobUtil.needsUploadDocumentSliceForParse(xml));
    }

    // ─── requiresLargeBodyParser ──────────────────────────────────────────────

    @IsTest
    static void testRequiresLargeBodyParser_Null() {
        System.assertEquals(true, FEC_MyCaseBlobUtil.requiresLargeBodyParser(null));
    }

    @IsTest
    static void testRequiresLargeBodyParser_SmallNoMarker() {
        Blob b = Blob.valueOf('<root><data>hello</data></root>');
        System.assertEquals(false, FEC_MyCaseBlobUtil.requiresLargeBodyParser(b));
    }

    @IsTest
    static void testRequiresLargeBodyParser_SmallWithMarker() {
        String xml = buildXmlWithUpload('SGVsbG8=');
        System.assertEquals(false, FEC_MyCaseBlobUtil.requiresLargeBodyParser(Blob.valueOf(xml)));
    }

    @IsTest
    static void testRequiresLargeBodyParser_LargeWithMarker() {
        FEC_MyCaseBlobUtil.MAX_DIRECT_BODY_BYTES = 10;
        String xml = buildXmlWithUpload('SGVsbG9Xb3JsZA==');
        System.assertEquals(true, FEC_MyCaseBlobUtil.requiresLargeBodyParser(Blob.valueOf(xml)));
    }

    // ─── toSafeAsciiXml ───────────────────────────────────────────────────────

    @IsTest
    static void testToSafeAsciiXml_Null() {
        System.assertEquals(null, FEC_MyCaseBlobUtil.toSafeAsciiXml(null));
    }

    @IsTest
    static void testToSafeAsciiXml_SmallNoUpload() {
        String xml = '<root><data>hello</data></root>';
        System.assertEquals(xml, FEC_MyCaseBlobUtil.toSafeAsciiXml(Blob.valueOf(xml)));
    }

    @IsTest
    static void testToSafeAsciiXml_SmallWithUpload() {
        // Below threshold → returns full string as-is
        String xml = buildXmlWithUpload('SGVsbG8=');
        System.assertEquals(xml, FEC_MyCaseBlobUtil.toSafeAsciiXml(Blob.valueOf(xml)));
    }

    @IsTest
    static void testToSafeAsciiXml_LargeWithUpload_ReturnsLiteXml() {
        FEC_MyCaseBlobUtil.MAX_DIRECT_BODY_BYTES = 10;
        String payload = 'SGVsbG9Xb3JsZA==';
        String xml = buildXmlWithUpload(payload);

        String result = FEC_MyCaseBlobUtil.toSafeAsciiXml(Blob.valueOf(xml));

        System.assertNotEquals(null, result);
        System.assert(result.contains(UPLOAD_ID_MARKER), 'liteXml must still contain the UploadDocument marker');
        System.assert(result.contains(VALUE_OPEN + VALUE_CLOSE), 'liteXml must have empty Value tag');
        System.assert(!result.contains(payload), 'liteXml must NOT contain the original base64 payload');
    }

    // ─── extractUploadDocumentSlice (Blob overload) ───────────────────────────

    @IsTest
    static void testExtractUploadDocumentSlice_NullBlob() {
        try {
            FEC_MyCaseBlobUtil.extractUploadDocumentSlice(null);
            System.assert(false, 'Expected SoapParseException');
        } catch (FEC_MyCaseSoapXml.SoapParseException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testExtractUploadDocumentSlice_NoMarker() {
        FEC_MyCaseBlobUtil.MAX_DIRECT_BODY_BYTES = 10;
        Blob b = Blob.valueOf('<root><data>no upload here long string padding</data></root>');
        try {
            FEC_MyCaseBlobUtil.extractUploadDocumentSlice(b);
            System.assert(false, 'Expected SoapParseException');
        } catch (FEC_MyCaseSoapXml.SoapParseException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testExtractUploadDocumentSlice_Valid() {
        FEC_MyCaseBlobUtil.MAX_DIRECT_BODY_BYTES = 10;
        String payload = 'SGVsbG9Xb3JsZA==';
        String xml = buildXmlWithUpload(payload);

        FEC_MyCaseBlobUtil.UploadDocumentSlice slice =
            FEC_MyCaseBlobUtil.extractUploadDocumentSlice(Blob.valueOf(xml));

        System.assertNotEquals(null, slice);
        System.assertEquals(payload, slice.uploadPayload);
        System.assert(slice.liteXml.contains(VALUE_OPEN + VALUE_CLOSE));
        System.assert(!slice.liteXml.contains(payload));
    }

    // ─── extractUploadDocumentSliceFromString ─────────────────────────────────

    @IsTest
    static void testExtractUploadDocumentSliceFromString_Blank() {
        try {
            FEC_MyCaseBlobUtil.extractUploadDocumentSliceFromString('');
            System.assert(false, 'Expected SoapParseException');
        } catch (FEC_MyCaseSoapXml.SoapParseException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testExtractUploadDocumentSliceFromString_NoMarker() {
        try {
            FEC_MyCaseBlobUtil.extractUploadDocumentSliceFromString('<root></root>');
            System.assert(false, 'Expected SoapParseException');
        } catch (FEC_MyCaseSoapXml.SoapParseException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testExtractUploadDocumentSliceFromString_NoValueOpen() {
        String xml = '<root>' + UPLOAD_ID_MARKER + '</root>';
        try {
            FEC_MyCaseBlobUtil.extractUploadDocumentSliceFromString(xml);
            System.assert(false, 'Expected SoapParseException');
        } catch (FEC_MyCaseSoapXml.SoapParseException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testExtractUploadDocumentSliceFromString_NoValueClose() {
        String xml = '<root>' + UPLOAD_ID_MARKER + VALUE_OPEN + 'content</root>';
        try {
            FEC_MyCaseBlobUtil.extractUploadDocumentSliceFromString(xml);
            System.assert(false, 'Expected SoapParseException');
        } catch (FEC_MyCaseSoapXml.SoapParseException ex) {
            System.assert(true);
        }
    }

    @IsTest
    static void testExtractUploadDocumentSliceFromString_Valid() {
        String payload = 'SGVsbG9Xb3JsZA==';
        String prefix = '<root>';
        String suffix = '</root>';
        String xml = prefix + UPLOAD_ID_MARKER + VALUE_OPEN + payload + VALUE_CLOSE + suffix;

        FEC_MyCaseBlobUtil.UploadDocumentSlice slice =
            FEC_MyCaseBlobUtil.extractUploadDocumentSliceFromString(xml);

        System.assertEquals(payload, slice.uploadPayload);
        System.assert(slice.liteXml.startsWith(prefix));
        System.assert(slice.liteXml.endsWith(suffix));
        System.assert(slice.liteXml.contains(VALUE_OPEN + VALUE_CLOSE));
        System.assert(!slice.liteXml.contains(payload));
    }

    @IsTest
    static void testExtractUploadDocumentSliceFromString_PayloadWithWhitespace() {
        String payload = '  SGVsbG9Xb3JsZA==  ';
        String xml = '<root>' + UPLOAD_ID_MARKER + VALUE_OPEN + payload + VALUE_CLOSE + '</root>';

        FEC_MyCaseBlobUtil.UploadDocumentSlice slice =
            FEC_MyCaseBlobUtil.extractUploadDocumentSliceFromString(xml);

        System.assertEquals(payload.trim(), slice.uploadPayload);
    }

    // ─── buildPayloadTooLargeException ────────────────────────────────────────

    @IsTest
    static void testBuildPayloadTooLargeException_WithSize() {
        FEC_MyCaseSoapXml.SoapParseException ex =
            FEC_MyCaseBlobUtil.buildPayloadTooLargeException(1024);
        System.assert(ex.getMessage().contains('1024'), 'Message should include byte count');
        System.assert(ex.getMessage().contains('Request body exceeds'));
    }

    @IsTest
    static void testBuildPayloadTooLargeException_ZeroSize() {
        FEC_MyCaseSoapXml.SoapParseException ex =
            FEC_MyCaseBlobUtil.buildPayloadTooLargeException(0);
        System.assert(ex.getMessage().contains('unknown'), 'Zero size should show "unknown"');
    }

    @IsTest
    static void testBuildPayloadTooLargeException_NullSize() {
        FEC_MyCaseSoapXml.SoapParseException ex =
            FEC_MyCaseBlobUtil.buildPayloadTooLargeException(null);
        System.assert(ex.getMessage().contains('unknown'), 'Null size should show "unknown"');
    }
}
