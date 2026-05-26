/**
 * Apex REST: nhận raw SOAP XML CreateCSCase, parse → FEC_CreateCSCaseService.CreateCSCaseRequest.
 *
 * Khi tạo Case: FEC_Is_Submited__c = true, FEC_Interaction_View_Mode__c = review (Interaction + Customer),
 * FEC_Channel__c = Sys.Channel trong XML (map qua FEC_MyCaseSoapXml).
 * //Thangtv
 *
 * URL: POST /services/apexrest/MyCase/v1/CreateCSCase
 * Content-Type: text/xml; charset=utf-8
 * SOAPAction (optional): urn:PegaRULES:SOAP:MyCase:Service#CreateCSCase
 */
@RestResource(urlMapping='/MyCase/v1/CreateCSCase')
global without sharing class FEC_CreateCSCaseRestService {
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
                    FEC_MyCaseSoapXml.buildErrorSoapResponse(
                        null,
                        System.Label.FEC_CS_CASE_ERROR_CODE,
                        System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
                    )
                );
                return;
            }

            FEC_CreateCSCaseService.CaseRequestType caseReq =
                FEC_MyCaseSoapXml.parseCreateCSCaseRequest(rawXml);
            FEC_CreateCSCaseService.CreateCSCaseResponse caseResp =
                FEC_CreateCSCaseService.CreateCSCaseRequest(caseReq);

            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildCreateCSCaseSoapResponse(caseResp)
            );
        } catch (FEC_MyCaseSoapXml.SoapParseException pe) {
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildErrorSoapResponse(
                    pe.transactionId,
                    pe.code,
                    pe.getMessage()
                )
            );
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                '[CreateCSCaseRest] ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            res.statusCode = FEC_ConstantCommon.ERROR_CODE_500_NUM;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildErrorSoapResponse(
                    null,
                    '500',
                    'Internal server error: ' + e.getMessage()
                )
            );
        }
    }
}