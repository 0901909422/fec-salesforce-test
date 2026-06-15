/**
 * Helpers for parsing large MyCase REST XML bodies without holding full body + base64 in DOM.
 * Apex String max ~6,000,000 chars. Do NOT convertToHex(entire blob) — hex doubles size and fails first.
 */
public without sharing class FEC_MyCaseBlobUtil {
    /** Bodies larger than this use UploadDocument slice before Dom.Document.load. */
    @TestVisible
    private static Integer MAX_DIRECT_BODY_BYTES = 5990000;
    @TestVisible
    private static final String UPLOAD_ID_MARKER = '<ID>UploadDocument</ID>';
    @TestVisible
    private static final String VALUE_OPEN = '<Value>';
    @TestVisible
    private static final String VALUE_CLOSE = '</Value>';

    public class UploadDocumentSlice {
        public String uploadPayload;
        public String liteXml;
    }

    public static Boolean requiresLargeBodyParser(Blob rawBody) {
        String bodyStr = blobToAsciiString(rawBody);
        if (bodyStr == null) {
            return true;
        }
        return needsUploadDocumentSlice(bodyStr);
    }

    public static String toSafeAsciiXml(Blob rawBody) {
        if (rawBody == null || rawBody.size() == 0) {
            return null;
        }
        String bodyStr = blobToAsciiString(rawBody);
        if (bodyStr == null) {
            throw buildPayloadTooLargeException(rawBody.size());
        }
        if (!needsUploadDocumentSlice(bodyStr)) {
            return bodyStr;
        }
        return extractUploadDocumentSliceFromString(bodyStr).liteXml;
    }

    public static UploadDocumentSlice extractUploadDocumentSlice(Blob rawBody) {
        if (rawBody == null || rawBody.size() == 0) {
            throw buildPayloadTooLargeException(0);
        }

        String bodyStr = blobToAsciiString(rawBody);
        if (bodyStr == null) {
            throw buildPayloadTooLargeException(rawBody.size());
        }
        return extractUploadDocumentSliceFromString(bodyStr);
    }

    @TestVisible
    private static String blobToAsciiString(Blob rawBody) {
        if (rawBody == null || rawBody.size() == 0) {
            return null;
        }
        try {
            return rawBody.toString();
        } catch (Exception ex) {
            return null;
        }
    }

    public static String blobToAsciiStringForParse(Blob rawBody) {
        return blobToAsciiString(rawBody);
    }

    @TestVisible
    private static Boolean needsUploadDocumentSlice(String bodyStr) {
        return bodyStr != null &&
            bodyStr.length() > MAX_DIRECT_BODY_BYTES &&
            bodyStr.indexOf(UPLOAD_ID_MARKER) >= 0;
    }

    public static Boolean needsUploadDocumentSliceForParse(String bodyStr) {
        return needsUploadDocumentSlice(bodyStr);
    }

    @TestVisible
    private static UploadDocumentSlice extractUploadDocumentSliceFromString(
        String bodyStr
    ) {
        if (String.isBlank(bodyStr)) {
            throw buildPayloadTooLargeException(0);
        }

        Integer idPos = bodyStr.indexOf(UPLOAD_ID_MARKER);
        if (idPos < 0) {
            throw buildPayloadTooLargeException(bodyStr.length());
        }

        Integer valueOpen = bodyStr.indexOf(VALUE_OPEN, idPos);
        if (valueOpen < 0) {
            throw buildPayloadTooLargeException(bodyStr.length());
        }

        Integer contentStart = valueOpen + VALUE_OPEN.length();
        Integer valueClose = bodyStr.indexOf(VALUE_CLOSE, contentStart);
        if (valueClose < 0) {
            throw buildPayloadTooLargeException(bodyStr.length());
        }

        String prefix = bodyStr.substring(0, valueOpen);
        String suffix = bodyStr.substring(valueClose + VALUE_CLOSE.length());
        String uploadPayload = bodyStr.substring(contentStart, valueClose);

        UploadDocumentSlice slice = new UploadDocumentSlice();
        slice.liteXml = prefix + VALUE_OPEN + VALUE_CLOSE + suffix;
        slice.uploadPayload = uploadPayload != null ? uploadPayload.trim() : null;
        return slice;
    }

    public static FEC_MyCaseSoapXml.SoapParseException buildPayloadTooLargeException(
        Integer bodySize
    ) {
        String sizeInfo = bodySize != null && bodySize > 0
            ? String.valueOf(bodySize)
            : 'unknown';
        return new FEC_MyCaseSoapXml.SoapParseException(
            null,
            System.Label.FEC_CS_CASE_ERROR_CODE,
            'Request body exceeds Apex 6MB limit (' +
                sizeInfo +
                ' bytes). Reduce UploadDocument size (recommended max ~4MB binary before base64) or split upload.'
        );
    }
}