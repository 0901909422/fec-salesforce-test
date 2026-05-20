/**
 * MRC Return — quy tắc hiển thị field trên Case Business.
 * FECREDIT_CSM_2025_KH-1269
 */
public without sharing class FEC_MrcReturnCaseService {
    public static final String MRC_RETURN = 'MRC Return';

    private static final Set<String> STAGE1_HIDDEN_FIELDS = new Set<String>{
        'FEC_Customer_Confirmation__c',
        'FEC_Contract_Processing_Assessment_Type__c'
    };

    /**
     * Stage 1 MRC Return / RL05: ẩn Customer Confirmation và Contract Processing Assessment Type.
     */
    public static Boolean shouldSkipStage1Field(
        String businessProcessCode,
        String subCategoryCode,
        String stageName,
        String fieldApiName
    ) {
        if (String.isBlank(fieldApiName) || !STAGE1_HIDDEN_FIELDS.contains(fieldApiName)) {
            return false;
        }
        if (String.isBlank(stageName) || !stageName.contains(FEC_ConstantCommon.STAGE_ONE)) {
            return false;
        }
        Boolean isMrcReturnProcess =
            String.isNotBlank(businessProcessCode) &&
            MRC_RETURN.equalsIgnoreCase(businessProcessCode.trim());
        Boolean isMrcRl05Branch =
            String.isNotBlank(subCategoryCode) &&
            subCategoryCode.toUpperCase().contains('RL05');
        return isMrcReturnProcess || isMrcRl05Branch;
    }
}
