/**
 * LWC fecCheckEligibleLoanSection: lấy số thẻ + (tuỳ chọn) số điện thoại từ bản ghi
 * Customer History mà Case trỏ tới qua lookup FEC_Account_or_Contract__c, rồi gọi FEC_CheckEligibleCallout.
 */
public with sharing class FEC_CheckEligibleController {

    @AuraEnabled
    public static FEC_CheckEligibleCallout.CheckEligibleResponse checkCustomerEligibility(Id caseId) {
        if (caseId == null) {
            return errMessageResponse(System.Label.FEC_MSG_Error_API_Label);
        }
        List<Case> caseRows = [
            SELECT Id, FEC_Account_or_Contract__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (caseRows.isEmpty()) {
            return errMessageResponse(System.Label.FEC_MSG_Error_API_Label);
        }
        Id chId = caseRows[0].FEC_Account_or_Contract__c;
        if (chId == null) {
            return errMessageResponse(System.Label.FEC_MSG_Error_API_Label);
        }

        List<FEC_Customer_History__c> chList = [
            SELECT FEC_Search_Result_National_ID__c, FEC_Primary_Phone__c
            FROM FEC_Customer_History__c
            WHERE Id = :chId
            LIMIT 1
        ];

        if (chList.isEmpty()) {
            return errMessageResponse(System.Label.FEC_MSG_Error_API_Label);
        }

        FEC_Customer_History__c ch = chList[0];
        String nationalId = resolveNationalIdFromSearchResult(ch.FEC_Search_Result_National_ID__c);
        if (String.isBlank(nationalId)) {
            return errMessageResponse(System.Label.FEC_MSG_Error_API_Label);
        }
        String phone = ch.FEC_Primary_Phone__c != null ? ch.FEC_Primary_Phone__c.trim() : null;
        if (String.isBlank(phone)) {
            phone = null;
        }

        String errId = validateIdParamForCallout(nationalId);
        if (errId != null) {
            return errMessageResponse(System.Label.FEC_MSG_Error_API_Label);
        }
        // Chuẩn hóa trước khi gọi (callout không trim/validate)
        String idForCallout = nationalId.trim();
        String phoneForCallout = phone;

        FEC_CheckEligibleCallout.CheckEligibleResponse response = FEC_CheckEligibleCallout.checkEligibility(
            idForCallout,
            phoneForCallout
        );
        if (response != null && String.isNotBlank(response.errorCode)) {
            response.errorMessage = System.Label.FEC_MSG_Error_API_Label;
        }
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

    private static String resolveNationalIdFromSearchResult(String searchResultNationalId) {
        List<String> parts = FEC_CommonUltils.parseSearchResultNationalIds(searchResultNationalId);
        if (parts.isEmpty()) {
            return null;
        }
        if (parts.size() == 1) {
            return parts[0];
        }

        String nationalId1 = parts[0];
        String nationalId2 = parts[1];
        String format1 = FEC_CommonUltils.getNationalIdFormat(nationalId1);
        String format2 = FEC_CommonUltils.getNationalIdFormat(nationalId2);

        if (format1 != format2) {
            if (isCccd(nationalId1)) {
                return nationalId1;
            }
            if (isCccd(nationalId2)) {
                return nationalId2;
            }
            return nationalId1;
        }
        return nationalId1;
    }

    private static Boolean isCccd(String value) {
        return String.isNotBlank(value) && Pattern.matches('^\\d{12}$', value.trim());
    }

    /**
     * Giá trị gán query ID_CARD_NUMBER: số CMND/CCCD/Passport.
     */
    private static String validateIdParamForCallout(String value) {
        if (String.isBlank(value)) {
            return System.Label.FEC_MSG_Error_API_Label;
        }
        String t = value.trim();
        // if (!Pattern.matches(FEC_ConstantCommon.PATTERN_NATIONAL_ID, t)) {
        //     return System.Label.FEC_MSG_National_ID_Invalid;
        // }
        return null;
    }
}