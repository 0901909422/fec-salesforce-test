// Toannd61 — Routing Action cho NOC Contract Closure RL16.02/RL16.03 (RD Payment Assessment)
public with sharing class FEC_RDPaymentContractAssessmentService {

    // Trả về map DeveloperName → {id, name} cho các Queue trong danh sách
    @AuraEnabled(cacheable=true)
    public static Map<String, Map<String, String>> getQueuesByDeveloperNames(List<String> developerNames) {
        Map<String, Map<String, String>> result = new Map<String, Map<String, String>>();
        if (developerNames == null || developerNames.isEmpty()) return result;
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
