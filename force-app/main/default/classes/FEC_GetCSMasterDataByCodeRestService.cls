/**
 * Apex REST: nhận raw SOAP XML GetCSMasterDataByCode → FEC_GetCSMasterDataByCodeService.
 *
 * URL: POST /services/apexrest/MyCase/v1/GetCSMasterDataByCode
 * Content-Type: text/xml; charset=utf-8
 * SOAPAction (optional): urn:PegaRULES:SOAP:MyCase:Service#GetCSMasterDataByCode
 */
@RestResource(urlMapping='/MyCase/v1/GetCSMasterDataByCode')
global without sharing class FEC_GetCSMasterDataByCodeRestService {
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
                    FEC_MyCaseSoapXml.buildGetCSMasterDataByCodeErrorSoapResponse(
                        null,
                        FEC_ConstantCommon.CODE_FAILURE,
                        System.Label.FEC_CS_CASE_REQUEST_IS_NULL_MSG
                    )
                );
                return;
            }

            FEC_MyCaseSoapXml.GetCSMasterDataByCodeParsedRequest parsed =
                FEC_MyCaseSoapXml.parseGetCSMasterDataByCodeRequest(rawXml);
            FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeResponse byCodeResp =
                FEC_GetCSMasterDataByCodeService.GetCSMasterDataByCodeRequest(
                    parsed.Sys,
                    parsed.MasterDataCode,
                    parsed.CustomerType,
                    parsed.AdditionalInfo,
                    parsed.Remarks
                );

            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_OK;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildGetCSMasterDataByCodeSoapResponse(byCodeResp)
            );
        } catch (FEC_MyCaseSoapXml.SoapParseException pe) {
            res.statusCode = FEC_ConstantCommon.HTTP_STATUS_BAD_REQUEST;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildGetCSMasterDataByCodeErrorSoapResponse(
                    pe.transactionId,
                    pe.code,
                    pe.getMessage()
                )
            );
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                '[GetCSMasterDataByCodeRest] ' + e.getMessage() + '\n' + e.getStackTraceString()
            );
            res.statusCode = FEC_ConstantCommon.ERROR_CODE_500_NUM;
            res.responseBody = Blob.valueOf(
                FEC_MyCaseSoapXml.buildGetCSMasterDataByCodeErrorSoapResponse(
                    null,
                    '500',
                    'Internal server error: ' + e.getMessage()
                )
            );
        }
    }
}