public with sharing class FEC_NewAssignmentController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getGeneralAssignmentNames(Id caseId) {
        List<Case> cases = [
            SELECT FEC_Product_Type__c, FEC_Category__c, FEC_SubCategory__c, FEC_SubCode__c
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) return new List<Map<String, String>>();

        Case c = cases[0];

        List<FEC_Nature_of_Case__c> nocs = [
            SELECT Id
            FROM FEC_Nature_of_Case__c
            WHERE FEC_Product_Type__c = :c.FEC_Product_Type__c
              AND FEC_Category__c = :c.FEC_Category__c
              AND FEC_Sub_Category__c = :c.FEC_SubCategory__c
              AND FEC_Sub_Code__c = :c.FEC_SubCode__c
            LIMIT 1
        ];
        if (nocs.isEmpty()) return new List<Map<String, String>>();

        List<FEC_General_Assignment__c> assignments = [
            SELECT Id, FEC_General_Assignment_Name__c
            FROM FEC_General_Assignment__c
            WHERE FEC_Nature_of_Cases__c = :nocs[0].Id
              AND FEC_Active__c = true
            ORDER BY FEC_General_Assignment_Name__c ASC
        ];

        List<Map<String, String>> result = new List<Map<String, String>>();
        for (FEC_General_Assignment__c ga : assignments) {
            result.add(new Map<String, String>{
                'label' => ga.FEC_General_Assignment_Name__c,
                'value' => ga.FEC_General_Assignment_Name__c
            });
        }
        return result;
    }

    @AuraEnabled
    public static Id createAssignment(
        Id caseId,
        String assignmentType,
        String assignmentStatus,
        String assignmentName
    ) {
        // Query Case để lấy Stage Name và check Default Stage (Stage 1)
        List<Case> cases = [
            SELECT FEC_Stage_Name__c,
                   FEC_Current_Case_Stage__c,
                   FEC_Current_Case_Stage__r.FEC_Default_Stage__c,
                   FEC_Current_Case_Stage__r.Name
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        if (cases.isEmpty()) throw new AuraHandledException(System.Label.FEC_NEW_ASSIGNMENT_ERR_CASE_NOT_FOUND);

        Case c = cases[0];

        // Tạo Assignment
        FEC_Assignment__c assignment = new FEC_Assignment__c(
            FEC_Case__c = caseId,
            FEC_Assignment_Type__c = assignmentType,
            FEC_Assignment_Status__c = assignmentStatus,
            FEC_Assignment_Name__c = assignmentName
        );
        insert assignment;

        // Luôn lưu Stage Name nếu có
        String stageName = String.isNotBlank(c.FEC_Stage_Name__c)
            ? c.FEC_Stage_Name__c
            : c.FEC_Current_Case_Stage__r?.Name;

        if (String.isNotBlank(stageName)) {
            insert new FEC_Case_Remarks__c(
                FEC_Case__c = caseId,
                FEC_Assignment__c = assignment.Id,
                FEC_Stage_Name__c = stageName,
                FEC_Remark_Type__c = FEC_ConstantCommon.REMARK_TYPE_ASSIGNMENT
            );
        }

        return assignment.Id;
    }
}
