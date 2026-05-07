// Toannd61 — Routing Action cho NOC Contract Closure RL16.02/RL16.03 (RD Payment Assessment)
public with sharing class FEC_RDPaymentContractAssessmentService {

    // Tên Queue cần fetch để build routingConfig
    private static final List<String> QUEUE_DEV_NAMES = new List<String>{
        FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME,
        FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME
    };

    // Mapping: API value của FEC_RD_Payment_Contract_Assessment__c → {team, queueDevName}
    // Cập nhật khi picklist API value thay đổi (phải deploy cùng field metadata)
    private static final Map<String, Map<String, String>> ROUTING_MAP =
        new Map<String, Map<String, String>>{
            FEC_ConstantCommon.RD_ASSESSMENT_CANNOT_CLOSE => new Map<String, String>{
                FEC_ConstantCommon.RD_ASSESSMENT_ROUTING_KEY_TEAM  => FEC_ConstantCommon.RD_ASSESSMENT_TEAM_SP,
                FEC_ConstantCommon.RD_ASSESSMENT_ROUTING_KEY_QUEUE => FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
            },
            FEC_ConstantCommon.RD_ASSESSMENT_CLOSE_WITH_STATEMENT => new Map<String, String>{
                FEC_ConstantCommon.RD_ASSESSMENT_ROUTING_KEY_TEAM  => FEC_ConstantCommon.RD_ASSESSMENT_TEAM_CC,
                FEC_ConstantCommon.RD_ASSESSMENT_ROUTING_KEY_QUEUE => FEC_ConstantCommon.QUEUE_DQ_CS_CUSTOMER_CARE_NAME
            },
            FEC_ConstantCommon.RD_ASSESSMENT_CLOSE_WITHOUT_STATEMENT => new Map<String, String>{
                FEC_ConstantCommon.RD_ASSESSMENT_ROUTING_KEY_TEAM  => FEC_ConstantCommon.RD_ASSESSMENT_TEAM_SP,
                FEC_ConstantCommon.RD_ASSESSMENT_ROUTING_KEY_QUEUE => FEC_ConstantCommon.QUEUE_DQ_CS_SUPPORT_NAME
            }
        };

    /**
     * Trả về toàn bộ config cần thiết cho routing RD Payment assessment:
     *   - routingMap : Map<assessmentApiValue, {team, queueDevName}>
     *   - queueMap   : Map<queueDevName, {id, name}>
     *
     * LWC dùng routingMap để resolve routing mà không cần hardcode picklist value.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRoutingConfig() {
        Map<String, Map<String, String>> queueMap = new Map<String, Map<String, String>>();
        for (Group g : [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
              AND DeveloperName IN :QUEUE_DEV_NAMES
        ]) {
            queueMap.put(g.DeveloperName, new Map<String, String>{
                'id'   => (String) g.Id,
                'name' => g.Name
            });
        }
        return new Map<String, Object>{
            'routingMap' => ROUTING_MAP,
            'queueMap'   => queueMap
        };
    }

    // Giữ lại để tương thích ngược nếu có nơi khác đang dùng
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