//PhongBT 28/05/26: Service dùng chung — cập nhật FEC_Assignment__c khi Route To theo team/queue (Bulk Import COF/GSR, tái sử dụng UI).
//PhongBT 28/05/26: Rule — (1) FEC_Assignment_Owner__c = null, (2) FEC_Submitted_On__c = thời điểm xử lý,
// (3) FEC_User_Role__c = null, (4) FEC_OwnerID__c = Group.Name, FEC_Team__c từ FEC_Team_Queue__c theo queue developer name.
public with sharing class FEC_BCH_AssignmentRouteToService {

    //PhongBT 28/05/26: Input bulk/single — assignment cần update và queue đích (developer name).
    public class RouteToContext {
        public Id assignmentId;
        public String queueDeveloperName;
        public Datetime submittedOn;
    }

    //PhongBT 28/05/26: Kết quả từng assignment sau update (success / errorMessage).
    public class ApplyResult {
        public Id assignmentId;
        public Boolean success;
        public String errorMessage;

        public ApplyResult(Id assignmentId) {
            this.assignmentId = assignmentId;
            this.success = false;
        }
    }

    //PhongBT 28/05/26: Resolve queue developer name từ FEC_Stage_Change__c.FEC_Next_Queue__c hoặc label Excel "Route to TEAM - QUEUE".
    public static String resolveQueueDeveloperName(
        String stageChangeQueueToken,
        String routeTeamHint,
        String routeQueueHint
    ) {
        //PhongBT 28/05/26: Ưu tiên token Stage Change (vd FEC_Quality_Control_Mailbox, FEC_DQ_Contract_Processing).
        if (String.isNotBlank(stageChangeQueueToken)) {
            return stageChangeQueueToken.trim();
        }
        if (String.isBlank(routeQueueHint)) {
            return null;
        }
        String queueHintNorm = normalizeToken(routeQueueHint);
        if (String.isBlank(queueHintNorm)) {
            return null;
        }
        //PhongBT 28/05/26: Khớp chính xác Group theo Name/DeveloperName từ hint queue.
        for (Group q : [
            SELECT DeveloperName, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND (
                DeveloperName = :routeQueueHint
                OR Name = :routeQueueHint
            )
            LIMIT 1
        ]) {
            if (String.isNotBlank(q.DeveloperName)) {
                return q.DeveloperName;
            }
        }
        //PhongBT 28/05/26: Map alias label Excel (vd Quality Control Mailbox → FEC_Quality_Control_Mailbox).
        String mappedDev = mapQueueHintToDeveloperName(queueHintNorm);
        if (String.isNotBlank(mappedDev)) {
            return mappedDev;
        }
        //PhongBT 28/05/26: Fallback fuzzy — so khớp normalize tên queue khi hint không trùng tuyệt đối.
        List<Group> fuzzy = [
            SELECT DeveloperName, Name
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 500
        ];
        for (Group q : fuzzy) {
            if (q == null) {
                continue;
            }
            if (normalizeToken(q.Name) == queueHintNorm || normalizeToken(q.DeveloperName) == queueHintNorm) {
                return q.DeveloperName;
            }
            if (normalizeToken(q.Name).contains(queueHintNorm) || queueHintNorm.contains(normalizeToken(q.Name))) {
                return q.DeveloperName;
            }
        }
        return null;
    }

    //PhongBT 28/05/26: Entry point 1 dòng — delegate sang bulk.
    public static ApplyResult applyRouteToAssignment(
        Id assignmentId,
        String queueDeveloperName,
        Datetime submittedOn
    ) {
        RouteToContext ctx = new RouteToContext();
        ctx.assignmentId = assignmentId;
        ctx.queueDeveloperName = queueDeveloperName;
        ctx.submittedOn = submittedOn == null ? System.now() : submittedOn;
        List<ApplyResult> results = applyRouteToAssignmentsBulk(new List<RouteToContext>{ ctx });
        if (results.isEmpty()) {
            ApplyResult empty = new ApplyResult(assignmentId);
            empty.errorMessage = 'Không có dữ liệu cập nhật Assignment.';
            return empty;
        }
        return results[0];
    }

    //PhongBT 28/05/26: Bulk update Assignment — lookup FEC_Team_Queue__c + Group rồi apply 4 rule spec.
    public static List<ApplyResult> applyRouteToAssignmentsBulk(List<RouteToContext> contexts) {
        List<ApplyResult> results = new List<ApplyResult>();
        if (contexts == null || contexts.isEmpty()) {
            return results;
        }

        Set<Id> assignmentIds = new Set<Id>();
        Set<String> queueDevNames = new Set<String>();
        Map<Id, RouteToContext> ctxByAssignmentId = new Map<Id, RouteToContext>();

        for (RouteToContext ctx : contexts) {
            ApplyResult rowResult = new ApplyResult(ctx == null ? null : ctx.assignmentId);
            results.add(rowResult);
            if (ctx == null || ctx.assignmentId == null) {
                rowResult.errorMessage = 'Thiếu Assignment Id.';
                continue;
            }
            if (String.isBlank(ctx.queueDeveloperName)) {
                rowResult.errorMessage = 'Không xác định được queue đích (FEC_Team_Queue__c).';
                continue;
            }
            assignmentIds.add(ctx.assignmentId);
            queueDevNames.add(ctx.queueDeveloperName.trim());
            ctxByAssignmentId.put(ctx.assignmentId, ctx);
        }

        if (assignmentIds.isEmpty()) {
            return results;
        }

        //PhongBT 28/05/26: Preload mapping queue developer name → team + Group.Name (tránh SOQL trong vòng lặp).
        Map<String, FEC_Team_Queue__c> teamQueueByDevName = loadTeamQueuesByDeveloperName(queueDevNames);
        Map<String, Group> queueByDevName = loadQueuesByDeveloperName(queueDevNames);

        List<FEC_Assignment__c> toUpdate = new List<FEC_Assignment__c>();
        Map<Id, ApplyResult> resultByAssignmentId = new Map<Id, ApplyResult>();
        for (ApplyResult r : results) {
            if (r.assignmentId != null) {
                resultByAssignmentId.put(r.assignmentId, r);
            }
        }

        for (Id assignmentId : assignmentIds) {
            ApplyResult rowResult = resultByAssignmentId.get(assignmentId);
            RouteToContext ctx = ctxByAssignmentId.get(assignmentId);
            if (rowResult == null || ctx == null) {
                continue;
            }
            String devName = ctx.queueDeveloperName.trim();
            FEC_Team_Queue__c teamQueue = teamQueueByDevName.get(devName);
            if (teamQueue == null) {
                rowResult.errorMessage =
                    'Không tìm thấy FEC_Team_Queue__c với FEC_Queue_Name__c = ' + devName + '.';
                continue;
            }
            Group targetQueue = queueByDevName.get(devName);
            if (targetQueue == null || String.isBlank(targetQueue.Name)) {
                rowResult.errorMessage =
                    'Không tìm thấy Queue với DeveloperName = ' + devName + '.';
                continue;
            }
            Datetime submitTs = ctx.submittedOn == null ? System.now() : ctx.submittedOn;
            //PhongBT 28/05/26: Gán đủ 4 field spec Route To Assignment.
            toUpdate.add(new FEC_Assignment__c(
                Id = assignmentId,
                FEC_Assignment_Owner__c = null,
                FEC_Submitted_On__c = submitTs,
                FEC_User_Role__c = null,
                FEC_OwnerID__c = targetQueue.Name,
                FEC_Team__c = teamQueue.FEC_Team__c
            ));
        }

        if (toUpdate.isEmpty()) {
            return results;
        }

        Database.SaveResult[] saveResults = Database.update(toUpdate, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            FEC_Assignment__c row = toUpdate[i];
            ApplyResult rowResult = resultByAssignmentId.get(row.Id);
            if (rowResult == null) {
                continue;
            }
            if (saveResults[i].isSuccess()) {
                rowResult.success = true;
                rowResult.errorMessage = null;
            } else {
                rowResult.errorMessage = saveResults[i].getErrors().isEmpty()
                    ? 'Cập nhật Assignment thất bại.'
                    : saveResults[i].getErrors()[0].getMessage();
            }
        }
        return results;
    }

    //PhongBT 28/05/26: Query FEC_Team_Queue__c — FEC_Queue_Name__c = queue developer name → FEC_Team__c.
    private static Map<String, FEC_Team_Queue__c> loadTeamQueuesByDeveloperName(Set<String> queueDevNames) {
        Map<String, FEC_Team_Queue__c> out = new Map<String, FEC_Team_Queue__c>();
        if (queueDevNames == null || queueDevNames.isEmpty()) {
            return out;
        }
        for (FEC_Team_Queue__c row : [
            SELECT FEC_Queue_Name__c, FEC_Team__c
            FROM FEC_Team_Queue__c
            WHERE FEC_Queue_Name__c IN :queueDevNames
        ]) {
            if (row != null && String.isNotBlank(row.FEC_Queue_Name__c)) {
                out.put(row.FEC_Queue_Name__c, row);
            }
        }
        return out;
    }

    //PhongBT 28/05/26: Query Group queue — lấy Name hiển thị gán FEC_OwnerID__c trên Assignment.
    private static Map<String, Group> loadQueuesByDeveloperName(Set<String> queueDevNames) {
        Map<String, Group> out = new Map<String, Group>();
        if (queueDevNames == null || queueDevNames.isEmpty()) {
            return out;
        }
        for (Group q : [
            SELECT Id, Name, DeveloperName
            FROM Group
            WHERE Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            AND DeveloperName IN :queueDevNames
        ]) {
            if (q != null && String.isNotBlank(q.DeveloperName)) {
                out.put(q.DeveloperName, q);
            }
        }
        return out;
    }

    //PhongBT 28/05/26: Alias queue từ label Excel (Route to CS QC - Quality Control Mailbox, ...).
    private static String mapQueueHintToDeveloperName(String queueHintNorm) {
        if (String.isBlank(queueHintNorm)) {
            return null;
        }
        Map<String, String> mapped = new Map<String, String>{
            'qualitycontrolmailbox' => FEC_ConstantCommon.QUEUE_QUALITY_CONTROL_MAILBOX_NAME,
            'dqcontractprocessing' => FEC_ConstantCommon.QUEUE_DQ_CONTRACT_PROCESSING_NAME,
            'contractprocessing' => FEC_ConstantCommon.QUEUE_DQ_CONTRACT_PROCESSING_NAME
        };
        return mapped.containsKey(queueHintNorm) ? mapped.get(queueHintNorm) : null;
    }

    //PhongBT 28/05/26: Chuẩn hóa chuỗi so khớp team/queue hint (bỏ space, ký tự đặc biệt, lowercase).
    private static String normalizeToken(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.trim().toLowerCase().replaceAll('\\s+', FEC_ConstantCommon.STR_EMPTY).replaceAll('[^a-z0-9]', '');
    }
}