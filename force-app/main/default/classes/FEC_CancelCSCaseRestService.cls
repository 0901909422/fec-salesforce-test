/**
 * Apex REST: nhận raw SOAP XML CancelCSCase → FEC_CancelCSCaseService.CancelCSCaseRequest.
 *
 * URL: POST /services/apexrest/MyCase/v1/CancelCSCase
 * Content-Type: text/xml; charset=utf-8
 * SOAPAction (optional): urn:PegaRULES:SOAP:MyCase:Service#CancelCSCase
 */
@RestResource(urlMapping='/MyCase/v1/CancelCSCase')
global without sharing class FEC_CancelCSCaseRestService {
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader(
            FEC_ConstantCommon.HTTP_HEADER_CONTENT_TYPE,
            FEC_ConstantCommon.API_CONTENT_TYPE
        );

        String rawXml = req.requestBody != null ? req.requestBody.toString() : null;

        try {
            if (String.isBlank(rawXml)) {
                res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
                res.responseBody = Blob.valueOf(
                    FEC_MyCaseSoapXml.buildCancelCSCaseErrorSoapResponse(
                        null,
                        FEC_ConstantCommon.CODE_FAILURE,
                        System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
                    )
                );
                return;
            }

            FEC_MyCaseSoapXml.CancelCSCaseParsedRequest parsed =
                FEC_MyCaseSoapXml.parseCancelCSCaseRequest(rawXml);
            FEC_CancelCSCaseService.CancelCSCaseResponseType cancelResp =
                FEC_CancelCSCaseService.CancelCSCaseRequest(
                    parsed.Sys,
                    parsed.CaseInfo
                );

            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildCancelCSCaseSoapResponse(cancelResp)
            );
        } catch (FEC_MyCaseSoapXml.SoapParseException pe) {
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildCancelCSCaseErrorSoapResponse(
                    pe.transactionId,
                    pe.code,
                    pe.getMessage()
                )
            );
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                '[CancelCSCaseRest] ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            res.statusCode = FEC_ConstantCommon.ERROR_CODE_500_NUM;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildCancelCSCaseErrorSoapResponse(
                    null,
                    '500',
                    'Internal server error: ' + e.getMessage()
                )
            );
        }
    }
}