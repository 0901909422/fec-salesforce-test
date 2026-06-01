/**
 * Apex REST: nhận raw SOAP XML GetCSMasterData → FEC_GetCSMasterDataService.GetCSMasterDataRequest.
 *
 * URL: POST /services/apexrest/MyCase/v1/GetCSMasterData
 * Content-Type: text/xml; charset=utf-8
 * SOAPAction (optional): urn:PegaRULES:SOAP:MyCase:Service#GetCSMasterData
 */
@RestResource(urlMapping='/MyCase/v1/GetCSMasterData')
global without sharing class FEC_GetCSMasterDataRestService {
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
                    FEC_MyCaseSoapXml.buildGetCSMasterDataErrorSoapResponse(
                        null,
                        FEC_ConstantCommon.CODE_FAILURE,
                        System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
                    )
                );
                return;
            }

            FEC_GetCSMasterDataService.SysRequestType sys =
                FEC_MyCaseSoapXml.parseGetCSMasterDataRequest(rawXml);

            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
            res.responseBody = Blob.valueOf(
                FEC_GetCSMasterDataService.buildGetCSMasterDataSoapXml(sys)
            );
        } catch (FEC_MyCaseSoapXml.SoapParseException pe) {
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildGetCSMasterDataErrorSoapResponse(
                    pe.transactionId,
                    pe.code,
                    pe.getMessage()
                )
            );
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                '[GetCSMasterDataRest] ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            res.statusCode = FEC_ConstantCommon.ERROR_CODE_500_NUM;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildGetCSMasterDataErrorSoapResponse(
                    null,
                    '500',
                    'Internal server error: ' + e.getMessage()
                )
            );
        }
    }
}