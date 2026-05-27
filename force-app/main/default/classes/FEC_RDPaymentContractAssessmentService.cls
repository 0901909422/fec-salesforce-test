// Toannd61 — RD Payment Assessment: filter assessment → FEC_Team_User_Group__c (query Stage Change)
public with sharing class FEC_RDPaymentContractAssessmentService {

    /** assessment → giá trị filter FEC_Team_User_Group__c khi query FEC_Stage_Change__c. */
    private static final Map<String, String> SCOPED_STAGE_TEAM_BY_ASSESSMENT =
        new Map<String, String>{
            FEC_ConstantCommon.RD_ASSESSMENT_CANNOT_CLOSE =>
                FEC_ConstantCommon.RD_ASSESSMENT_TEAM_CS_SUPPORT,
            FEC_ConstantCommon.RD_ASSESSMENT_CLOSE_WITH_STATEMENT =>
                FEC_ConstantCommon.RD_ASSESSMENT_TEAM_CS_CUSTOMER_CARE,
            FEC_ConstantCommon.RD_ASSESSMENT_CLOSE_WITHOUT_STATEMENT =>
                FEC_ConstantCommon.RD_ASSESSMENT_TEAM_CONTRACT_PROCESSING
        };

    /**
     * Trả về assessment → FEC_Team_User_Group__c filter (query FEC_Stage_Change__c).
     * Team/Queue UI lấy từ FEC_Stage_Change__c.FEC_Team_User_Group__c / FEC_Next_Queue__c.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRoutingConfig() {
        return new Map<String, Object>{
            'scopedStageTeamByAssessment' => SCOPED_STAGE_TEAM_BY_ASSESSMENT
        };
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getScopedStageTeamByAssessment() {
        return SCOPED_STAGE_TEAM_BY_ASSESSMENT.clone();
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, String>> getQueuesByDeveloperNames(List<String> developerNames) {
        Map<String, Map<String, String>> result = new Map<String, Map<String, String>>();
        if (developerNames == null || developerNames.isEmpty()) {
            return result;
        }
        for (Group g : [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
              AND DeveloperName IN :developerNames
        ]) {
            result.put(g.DeveloperName, new Map<String, String>{
                'id'   => (String) g.Id,
                'name' => g.Name
            });
        }
        return result;
    }
}
