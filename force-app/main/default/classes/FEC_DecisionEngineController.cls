/**
 * @deprecated MDM CRUD methods moved to FEC_StageTransitionEngine.
 *             Only utility methods (getStatusNameByStageId, getMDMStatusNameByStageId) remain.
 */
public with sharing class FEC_DecisionEngineController {

    // ════════════════════════════════════════════════════════
    // PUBLIC: GET STATUS NAME BY STAGE ID
    // ════════════════════════════════════════════════════════

    /**
     * @description Lấy Status Name tương ứng của một Stage.
     *              Khi chuyển Stage, gọi method này để lấy Status Name rồi set vào Case.Status.
     * @param stageId Id của FEC_Case_Stage__c (Live) hoặc FEC_MDM_Case_Stage__c (MDM)
     * @return String Status Name của Stage, null nếu không tìm thấy
     * 
     * Usage example (trong FEC_CaseBusinessService khi route):
     *   String statusName = FEC_DecisionEngineController.getStatusNameByStageId(nextStageId);
     *   if (String.isNotBlank(statusName)) {
     *       updatedCase.Status = statusName;
     *   }
     */
    public static String getStatusNameByStageId(Id stageId) {
        if (stageId == null) return null;
        List<FEC_Case_Stage__c> stages = [
            SELECT FEC_Status_Name__c
            FROM FEC_Case_Stage__c
            WHERE Id = :stageId
            LIMIT 1
        ];
        if (!stages.isEmpty() && String.isNotBlank(stages[0].FEC_Status_Name__c)) {
            return stages[0].FEC_Status_Name__c;
        }
        return null;
    }

    /**
     * @description Lấy Status Name từ MDM Stage.
     * @param stageId Id của FEC_MDM_Case_Stage__c
     * @return String Status Name
     */
    public static String getMDMStatusNameByStageId(Id stageId) {
        if (stageId == null) return null;
        List<FEC_MDM_Case_Stage__c> stages = [
            SELECT FEC_Status_Name__c
            FROM FEC_MDM_Case_Stage__c
            WHERE Id = :stageId
            LIMIT 1
        ];
        if (!stages.isEmpty() && String.isNotBlank(stages[0].FEC_Status_Name__c)) {
            return stages[0].FEC_Status_Name__c;
        }
        return null;
    }
}