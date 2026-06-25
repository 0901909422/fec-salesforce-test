//PhongBT 02/06/26: COF/GSR bulk import — Route To level Case tạo FEC_Assignment__c theo ruleroutingactionvoicofgsr.xlsx.
public with sharing class FEC_BCH_CofGsrImportRouteToService {

    public class CreateContext {
        public FEC_BatchCaseHandlingImportRow row;
        public Id caseId;
        public String routeActionLabel;
        public String queueDeveloperName;
        public String inputtedRemarks;
        public Datetime submittedOn;
    }

    public class ApplyResult {
        public Id caseId;
        public Boolean success;
        public String errorMessage;

        public ApplyResult(Id caseId) {
            this.caseId = caseId;
            this.success = false;
        }
    }

    public static Boolean isCofGsrRouteToImportLabel(String label) {
        if (String.isBlank(label)) {
            return false;
        }
        String norm = label.trim().toLowerCase();
        return norm.startsWith('route to') && norm.contains('-');
    }

    public static String parseQueueLabelFromRouteAction(String routeActionLabel) {
        if (String.isBlank(routeActionLabel)) {
            return null;
        }
        String raw = routeActionLabel.trim();
        Integer dashPos = raw.lastIndexOf('-');
        if (dashPos < 0 || dashPos >= raw.length() - 1) {
            return null;
        }
        return raw.substring(dashPos + 1).trim();
    }

    public static String parseTeamHintFromRouteAction(String routeActionLabel) {
        if (String.isBlank(routeActionLabel)) {
            return null;
        }
        String raw = routeActionLabel.trim();
        String prefix = 'route to';
        if (!raw.toLowerCase().startsWith(prefix)) {
            return null;
        }
        String tail = raw.substring(prefix.length()).trim();
        Integer dashPos = tail.indexOf('-');
        if (dashPos <= 0) {
            return String.isBlank(tail) ? null : tail.trim();
        }
        return tail.substring(0, dashPos).trim();
    }

    public static Boolean isRouteToLabelResolvable(String routeActionLabel) {
        return String.isNotBlank(resolveQueueDeveloperNameForImport(routeActionLabel));
    }

    public static String resolveQueueDeveloperNameForImport(String routeActionLabel) {
        String queueLabel = parseQueueLabelFromRouteAction(routeActionLabel);
        String teamHint = parseTeamHintFromRouteAction(routeActionLabel);
        return FEC_BCH_AssignmentRouteToService.resolveQueueDeveloperName(
            null,
            teamHint,
            queueLabel
        );
    }

    public static void collectCreateContext(
        FEC_BatchCaseHandlingImportRow row,
        Id caseId,
        String routeActionLabel,
        List<CreateContext> target
    ) {
        if (row == null || caseId == null || target == null || String.isBlank(routeActionLabel)) {
            return;
        }
        if (!isCofGsrRouteToImportLabel(routeActionLabel)) {
            return;
        }
        CreateContext ctx = new CreateContext();
        ctx.row = row;
        ctx.caseId = caseId;
        ctx.routeActionLabel = routeActionLabel.trim();
        ctx.inputtedRemarks = row.inputtedRemarks;
        ctx.submittedOn = System.now();
        target.add(ctx);
    }

    public static void applyCreateRoutingAssignmentsBulk(
        List<CreateContext> contexts,
        Map<Id, Case> caseLiteById
    ) {
        if (contexts == null || contexts.isEmpty()) {
            return;
        }
        Map<Id, List<CreateContext>> ctxByCaseId = new Map<Id, List<CreateContext>>();
        Set<String> queueDevNames = new Set<String>();
        for (CreateContext ctx : contexts) {
            if (ctx == null || ctx.caseId == null || ctx.row == null || String.isBlank(ctx.routeActionLabel)) {
                continue;
            }
            String devName = resolveQueueDeveloperNameForImport(ctx.routeActionLabel);
            if (String.isBlank(devName)) {
                markRowFailed(
                    ctx.row,
                    'Không map được queue từ Routing Action: ' + ctx.routeActionLabel
                );
                continue;
            }
            ctx.queueDeveloperName = devName;
            queueDevNames.add(devName);
            if (!ctxByCaseId.containsKey(ctx.caseId)) {
                ctxByCaseId.put(ctx.caseId, new List<CreateContext>());
            }
            ctxByCaseId.get(ctx.caseId).add(ctx);
        }
        if (queueDevNames.isEmpty()) {
            return;
        }

        Map<String, FEC_Team_Queue__c> teamQueueByDev = loadTeamQueues(queueDevNames);
        Map<String, Group> queueByDev = loadQueues(queueDevNames);
        List<FEC_Assignment__c> inserts = new List<FEC_Assignment__c>();
        Map<Integer, CreateContext> insertIndexToCtx = new Map<Integer, CreateContext>();

        for (Id caseId : ctxByCaseId.keySet()) {
            Case caseLite = caseLiteById == null ? null : caseLiteById.get(caseId);
            String caseOwnerTeam = resolveCaseOwnerTeam(caseLite);
            for (CreateContext ctx : ctxByCaseId.get(caseId)) {
                String devName = ctx.queueDeveloperName;
                FEC_Team_Queue__c teamQueue = teamQueueByDev.get(devName);
                Group targetQueue = queueByDev.get(devName);
                if (teamQueue == null || targetQueue == null || String.isBlank(targetQueue.Name)) {
                    markRowFailed(
                        ctx.row,
                        'Không tìm thấy FEC_Team_Queue__c / Queue cho: ' + devName
                    );
                    continue;
                }
                String teamCode = teamQueue.FEC_Team__c;
                FEC_Assignment__c asg = new FEC_Assignment__c(
                    FEC_Case__c = caseId,
                    FEC_Assignment_Name__c = FEC_ConstantCommon.ASSIGNMENT_NAME_ROUTING,
                    FEC_Assignment_Type__c = FEC_ConstantCommon.ASSIGNMENT_TYPE_ROUTING,
                    FEC_Assignment_Owner__c = null,
                    FEC_User_Role__c = null,
                    FEC_OwnerID__c = targetQueue.Name,
                    FEC_Team__c = teamCode,
                    FEC_Assignment_Status__c = FEC_CofGsrAssignmentService.resolveAssignmentStatusWithOwner(
                        teamCode,
                        caseOwnerTeam
                    ),
                    FEC_Manual__c = false,
                    FEC_Submitted_On__c = ctx.submittedOn == null ? System.now() : ctx.submittedOn,
                    FEC_Assignment_Remark__c = ctx.inputtedRemarks
                );
                insertIndexToCtx.put(inserts.size(), ctx);
                inserts.add(asg);
            }
        }

        if (inserts.isEmpty()) {
            return;
        }

        Set<Id> insertedAssignmentIds = new Set<Id>();
        Map<Id, CreateContext> insertedAssignmentIdToCtx = new Map<Id, CreateContext>();

        Database.SaveResult[] saveResults = Database.insert(inserts, false);
        for (Integer i = 0; i < saveResults.size(); i++) {
            CreateContext ctx = insertIndexToCtx.get(i);
            if (ctx == null || ctx.row == null) {
                continue;
            }
            if (saveResults[i].isSuccess()) {
                // 25/06/2026 PhongBT: tạo Routing Action History cho mỗi Assignment được sinh ra
                Id newAssignmentId = saveResults[i].getId();
                insertedAssignmentIds.add(newAssignmentId);
                insertedAssignmentIdToCtx.put(newAssignmentId, ctx);
                continue;
            }
            String message = saveResults[i].getErrors().isEmpty()
                ? 'Tạo Assignment Route To thất bại.'
                : saveResults[i].getErrors()[0].getMessage();
            markRowFailed(ctx.row, message);
        }

        // 25/06/2026 PhongBT: tạo Routing Action History cho các Assignment vừa insert thành công
        if (!insertedAssignmentIds.isEmpty()) {
            createRoutingHistoriesForInsertedAssignments(insertedAssignmentIds, insertedAssignmentIdToCtx, caseLiteById);
        }
    }

    // 25/06/2026 PhongBT: tạo FEC_Routing_Action_History__c (FEC_Routing_Action_Type__c = Case)
    // ứng với mỗi Assignment được sinh ra từ COF/GSR Case-level Route To import
    private static void createRoutingHistoriesForInsertedAssignments(
        Set<Id> assignmentIds,
        Map<Id, CreateContext> ctxByAssignmentId,
        Map<Id, Case> caseLiteById
    ) {
        if (assignmentIds == null || assignmentIds.isEmpty()) {
            return;
        }

        // Reload assignments để lấy FEC_OwnerID__c (tên queue) sau insert
        Map<Id, FEC_Assignment__c> assignmentById = new Map<Id, FEC_Assignment__c>([
            SELECT Id, FEC_Case__c, FEC_OwnerID__c, FEC_Team__c
            FROM FEC_Assignment__c
            WHERE Id IN :assignmentIds
        ]);

        // Load importer user
        List<User> importerRows = [
            SELECT Id, Email, UserRole.Name
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (importerRows.isEmpty()) {
            return;
        }
        User importer = importerRows[0];
        String importerEmailId = FEC_CaseBusinessService.emailLocalPart(importer.Email);

        // Collect case IDs để reload Case sau assignment insert
        Set<Id> caseIds = new Set<Id>();
        for (FEC_Assignment__c asg : assignmentById.values()) {
            if (asg != null && asg.FEC_Case__c != null) {
                caseIds.add(asg.FEC_Case__c);
            }
        }
        Map<Id, Case> caseAfterById = caseIds.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                SELECT Id, OwnerId, Owner.Name, Owner.Type, FEC_Final_Status__c,
                       FEC_Current_Case_Stage__c, FEC_Current_Case_Stage__r.FEC_Code__c
                FROM Case
                WHERE Id IN :caseIds
            ]);

        List<FEC_Routing_Action_History__c> histories = new List<FEC_Routing_Action_History__c>();
        for (Id assignmentId : assignmentById.keySet()) {
            FEC_Assignment__c asg = assignmentById.get(assignmentId);
            if (asg == null || asg.FEC_Case__c == null) {
                continue;
            }
            CreateContext ctx = ctxByAssignmentId.get(assignmentId);
            if (ctx == null) {
                continue;
            }
            Case caseAfter = caseAfterById.get(asg.FEC_Case__c);
            Case caseLite = caseLiteById == null ? null : caseLiteById.get(asg.FEC_Case__c);

            // FEC_Original_User_Queue__c = Queue/Email của Owner Case tại thời điểm routing
            String originalLabel = caseLite != null
                ? FEC_CaseBusinessService.resolveRoutingHistoryOwnerLabel(caseLite.OwnerId, null)
                : null;
            String originalId = caseLite != null && caseLite.OwnerId != null
                ? String.valueOf(caseLite.OwnerId)
                : null;

            // FEC_Updated_User_Queue__c = Queue/Email của Owner Assignment (FEC_OwnerID__c = tên queue)
            String updatedLabel = asg.FEC_OwnerID__c;
            String updatedId = null;
            if (String.isNotBlank(asg.FEC_OwnerID__c)) {
                List<Group> queues = [
                    SELECT Id, Name
                    FROM Group
                    WHERE Name = :asg.FEC_OwnerID__c
                    AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
                    LIMIT 1
                ];
                if (!queues.isEmpty()) {
                    updatedId = String.valueOf(queues[0].Id);
                }
            }

            String stageName = caseLite != null
                ? caseLite.FEC_Current_Case_Stage__r?.FEC_Code__c
                : null;
            if (String.isBlank(stageName) && caseAfter != null) {
                stageName = caseAfter.FEC_Current_Case_Stage__r?.FEC_Code__c;
            }

            String finalStatusBefore = caseAfter != null ? caseAfter.FEC_Final_Status__c : null;

            FEC_Routing_Action_History__c history = new FEC_Routing_Action_History__c(
                FEC_Routing_Action__c       = FEC_ConstantCommon.CASE_ROUTING_ACTION,
                FEC_Routing_Action_Type__c  = 'Case',
                FEC_Case__c                 = asg.FEC_Case__c,
                FEC_Assignment__c           = assignmentId,
                FEC_Original_User_Queue__c  = originalLabel,
                FEC_Original_User_Queue_ID__c = originalId,
                FEC_Updated_User_Queue__c   = updatedLabel,
                FEC_Updated_User_Queue_ID__c = updatedId,
                FEC_User__c                 = importerEmailId,
                FEC_User_Role__c            = importer.UserRole?.Name,
                FEC_Perform_User__c         = importer.Id,
                FEC_Stage_Name__c           = stageName,
                FEC_Current_Status__c       = finalStatusBefore,
                FEC_Submitted_On__c         = ctx.submittedOn == null ? System.now() : ctx.submittedOn
            );
            histories.add(history);
        }

        if (!histories.isEmpty()) {
            Database.insert(histories, false);
        }
    }

    private static void markRowFailed(FEC_BatchCaseHandlingImportRow row, String message) {
        if (row == null) {
            return;
        }
        row.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
        row.errors = String.isBlank(row.errors) ? message : row.errors + ',\n' + message;
    }

    private static Map<String, FEC_Team_Queue__c> loadTeamQueues(Set<String> queueDevNames) {
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

    private static Map<String, Group> loadQueues(Set<String> queueDevNames) {
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

    private static String resolveCaseOwnerTeam(Case caseLite) {
        if (caseLite == null || caseLite.OwnerId == null) {
            return null;
        }
        if (caseLite.OwnerId.getSObjectType() != Group.SObjectType) {
            return null;
        }
        List<Group> ownerQueues = [
            SELECT DeveloperName
            FROM Group
            WHERE Id = :caseLite.OwnerId
            AND Type = :FEC_ConstantCommon.GROUP_TYPE_QUEUE
            LIMIT 1
        ];
        if (ownerQueues.isEmpty() || String.isBlank(ownerQueues[0].DeveloperName)) {
            return null;
        }
        List<FEC_Team_Queue__c> rows = [
            SELECT FEC_Team__c
            FROM FEC_Team_Queue__c
            WHERE FEC_Queue_Name__c = :ownerQueues[0].DeveloperName
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0].FEC_Team__c;
    }
}
