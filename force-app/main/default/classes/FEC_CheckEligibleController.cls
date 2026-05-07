/**
 * LWC fecCheckEligibleLoanSection: lấy số thẻ + (tuỳ chọn) số điện thoại từ bản ghi
 * Customer History mà Case trỏ tới qua lookup FEC_Account_or_Contract__c, rồi gọi FEC_CheckEligibleCallout.
 */
public with sharing class FEC_CheckEligibleController {

    @AuraEnabled
    public static FEC_CheckEligibleCallout.CheckEligibleResponse checkCustomerEligibility(Id caseId) {
        if (caseId == null) {
            return errResponse(
                FEC_ConstantCommon.ERROR_CODE_VALIDATION,
                String.format(System.Label.FEC_MSG_Param_Required, new List<String>{ 'Case Id' })
            );
        }
        List<Case> caseRows = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseRows.isEmpty()) {
            return errResponse(FEC_ConstantCommon.ERROR_CODE_VALIDATION, 'Case not found');
        }
        Id chId = caseRows[0].FEC_Account_or_Contract__c;
        if (chId == null) {
            return errMessageResponse(System.Label.FEC_MSG_CheckEligible_No_Matching_History);
        }

        List<FEC_Customer_History__c> chList = [
            SELECT FEC_Card_Number__c, FEC_Primary_Phone__c
            FROM FEC_Customer_History__c
            WHERE Id = :chId
            LIMIT 1
        ];

        if (chList.isEmpty()) {
            return errMessageResponse(System.Label.FEC_MSG_CheckEligible_No_Matching_History);
        }

        FEC_Customer_History__c ch = chList[0];
        String cardNum = ch.FEC_Card_Number__c != null ? ch.FEC_Card_Number__c.trim() : null;
        if (String.isBlank(cardNum)) {
            return errMessageResponse(System.Label.FEC_MSG_CheckEligible_Card_Not_Found);
        }
        String phone = ch.FEC_Primary_Phone__c != null ? ch.FEC_Primary_Phone__c.trim() : null;
        if (String.isBlank(phone)) {
            phone = null;
        }

        String errId = validateIdParamForCallout(cardNum);
        if (errId != null) {
            return errResponse(FEC_ConstantCommon.ERROR_CODE_VALIDATION, errId);
        }
        // Chuẩn hóa trước khi gọi (callout không trim/validate)
        String idForCallout = cardNum.trim();
        String phoneForCallout = phone;

        FEC_CheckEligibleCallout.CheckEligibleResponse response = FEC_CheckEligibleCallout.checkEligibility(
            idForCallout,
            phoneForCallout
        );
        FEC_CheckEligibleCallout.logApiResponse();
        return response;
    }

    private static FEC_CheckEligibleCallout.CheckEligibleResponse errResponse(
        String errorCode,
        String errorMessage
    ) {
        FEC_CheckEligibleCallout.CheckEligibleResponse r = new FEC_CheckEligibleCallout.CheckEligibleResponse();
        r.Status = 'false';
        r.errorCode = errorCode;
        r.errorMessage = errorMessage;
        return r;
    }

    private static FEC_CheckEligibleCallout.CheckEligibleResponse errMessageResponse(String userMessage) {
        return errResponse('CASE_RESOLUTION', userMessage);
    }

    /**
     * Giá trị gán query ID_CARD_NUMBER: số thẻ, 4–20 chữ số (sau trim).
     */
    private static String validateIdParamForCallout(String value) {
        if (String.isBlank(value)) {
            return String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{ 'ID_CARD_NUMBER' }
            );
        }
        String t = value.trim();
        if (!Pattern.compile('^\\d{4,20}$').matcher(t).matches()) {
            return String.format(
                System.Label.FEC_MSG_Param_Required,
                new List<String>{ 'ID_CARD_NUMBER' }
            );
        }
        return null;
    }
}
