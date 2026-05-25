/**
 * Resolves Excel routing labels to stage screens, action buttons, and run parameters
 * per Design - Batch Processing.xlsx (Logic xử lý Import).
 */
public with sharing class FEC_BCH_ImportRoutingResolver {

    public class ResolvedRouting {
        public String methodKey;
        public Id actionButtonId;
        public String decision;
        public String routingActionValue;
        public String routeTeamHint;
        public String routeQueueHint;
        public Boolean matchedStageScreen;
        public Boolean routeViaRevertButton;
        public Boolean revertPreferRevertedChange;
    }

    private class StageScreenRow {
        public Id screenId;
        public Id stageId;
        public Id actionButtonId;
        public String actionButtonCode;
        public String screenCode;
        public String customLabel;
        public String fieldType;
    }

    private static Map<Id, List<StageScreenRow>> screensByStageId = new Map<Id, List<StageScreenRow>>();

    public static void clearCache() {
        screensByStageId.clear();
    }

    public static void preloadStageScreens(Set<Id> stageIds, String userGroup) {
        clearCache();
        if (stageIds == null || stageIds.isEmpty()) {
            return;
        }
        String ug = String.isBlank(userGroup) ? FEC_ConstantCommon.STR_EMPTY : userGroup.trim();
        List<FEC_Stage_Screen__c> rows = [
            SELECT
                Id,
                FEC_Case_Stage__c,
                FEC_Code__c,
                FEC_Custom_Action_Button_Label__c,
                FEC_Field_Type__c,
                FEC_Action_Button__c,
                FEC_Action_Button__r.FEC_Code__c,
                FEC_User_Group__c
            FROM FEC_Stage_Screen__c
            WHERE FEC_Case_Stage__c IN :stageIds
            AND FEC_Active__c = TRUE
            AND FEC_Action_Button__c != NULL
            AND FEC_Action_Button__r.FEC_Type__c = 'Routing Action'
        ];
        for (FEC_Stage_Screen__c row : rows) {
            if (row == null || row.FEC_Case_Stage__c == null) {
                continue;
            }
            if (String.isNotBlank(ug) && String.isNotBlank(row.FEC_User_Group__c) && !row.FEC_User_Group__c.contains(ug)) {
                continue;
            }
            StageScreenRow item = new StageScreenRow();
            item.screenId = row.Id;
            item.stageId = row.FEC_Case_Stage__c;
            item.actionButtonId = row.FEC_Action_Button__c;
            SObject actionButton = row.getSObject('FEC_Action_Button__r');
            item.actionButtonCode = actionButton == null || actionButton.get('FEC_Code__c') == null
                ? FEC_ConstantCommon.STR_EMPTY
                : String.valueOf(actionButton.get('FEC_Code__c'));
            item.screenCode = row.FEC_Code__c;
            item.customLabel = row.FEC_Custom_Action_Button_Label__c;
            item.fieldType = row.FEC_Field_Type__c;
            if (!screensByStageId.containsKey(item.stageId)) {
                screensByStageId.put(item.stageId, new List<StageScreenRow>());
            }
            screensByStageId.get(item.stageId).add(item);
        }
    }

    public static ResolvedRouting resolve(Id stageId, String excelRoutingLabel) {
        ResolvedRouting out = new ResolvedRouting();
        out.matchedStageScreen = false;
        out.routeViaRevertButton = false;
        out.revertPreferRevertedChange = false;
        if (stageId == null || String.isBlank(excelRoutingLabel)) {
            return out;
        }
        String raw = excelRoutingLabel.trim();
        out.routingActionValue = raw;
        String methodFromMap = resolveMethodKeyFromMap(raw);
        if (String.isNotBlank(methodFromMap)) {
            out.methodKey = methodFromMap;
        }
        ParsedPattern parsed = parseExcelPattern(raw);
        if (String.isBlank(out.methodKey) && String.isNotBlank(parsed.methodKey)) {
            out.methodKey = parsed.methodKey;
        }
        out.decision = parsed.decision;
        out.routeTeamHint = parsed.routeTeamHint;
        out.routeQueueHint = parsed.routeQueueHint;
        if (parsed.routeViaRevertButton == true) {
            out.routeViaRevertButton = true;
        }
        if (parsed.revertPreferRevertedChange == true) {
            out.revertPreferRevertedChange = true;
        }
        List<StageScreenRow> screens = screensByStageId.get(stageId);
        if (screens == null || screens.isEmpty()) {
            return out;
        }
        String normExcel = normalizeToken(raw);
        StageScreenRow matched = matchStageScreen(screens, out, parsed, normExcel);
        if (matched != null) {
            out.matchedStageScreen = true;
            out.actionButtonId = matched.actionButtonId;
            if (String.isNotBlank(matched.actionButtonCode)) {
                out.methodKey = matched.actionButtonCode;
            }
        }
        if (out.methodKey == FEC_CaseBusinessService.UPDATEACTION && String.isBlank(out.decision) && String.isNotBlank(parsed.decision)) {
            out.decision = parsed.decision;
        }
        return out;
    }

    public static Boolean requiresStageScreenMatch(String methodKey) {
        if (String.isBlank(methodKey)) {
            return true;
        }
        return methodKey != FEC_CaseBusinessService.TRANSFER;
    }

    private static StageScreenRow matchStageScreen(
        List<StageScreenRow> screens,
        ResolvedRouting out,
        ParsedPattern parsed,
        String normExcel
    ) {
        if (screens == null || screens.isEmpty()) {
            return null;
        }
        String targetMethod = out.methodKey;
        if (String.isBlank(targetMethod)) {
            return null;
        }
        if (targetMethod == FEC_CaseBusinessService.ESCALATE || targetMethod == FEC_CaseBusinessService.REJECT) {
            for (StageScreenRow s : screens) {
                if (targetMethod.equalsIgnoreCase(s.actionButtonCode) || targetMethod.equalsIgnoreCase(s.screenCode)) {
                    return s;
                }
            }
            for (StageScreenRow s : screens) {
                if (targetMethod.equalsIgnoreCase(s.actionButtonCode)) {
                    return s;
                }
            }
            return null;
        }
        if (targetMethod == FEC_CaseBusinessService.REVERT) {
            Boolean wantTeamQueue = parsed.revertPreferRevertedChange == true || normExcel.contains('teamqueue');
            for (StageScreenRow s : screens) {
                if (!FEC_CaseBusinessService.REVERT.equalsIgnoreCase(s.actionButtonCode)) {
                    continue;
                }
                if (wantTeamQueue && s.fieldType == 'Revert') {
                    return s;
                }
                if (!wantTeamQueue && (s.fieldType == 'New' || s.fieldType == 'All' || String.isBlank(s.fieldType))) {
                    return s;
                }
            }
            for (StageScreenRow s : screens) {
                if (FEC_CaseBusinessService.REVERT.equalsIgnoreCase(s.actionButtonCode)) {
                    return s;
                }
            }
            return null;
        }
        if (targetMethod == FEC_CaseBusinessService.ROUTE_TO) {
            String teamNorm = normalizeToken(out.routeTeamHint);
            String queueNorm = normalizeToken(out.routeQueueHint);
            for (StageScreenRow s : screens) {
                if (!FEC_CaseBusinessService.ROUTE_TO.equalsIgnoreCase(s.actionButtonCode)) {
                    continue;
                }
                String labelNorm = normalizeToken(buildScreenDisplayLabel(s));
                if (String.isNotBlank(normExcel) && labelNorm == normExcel) {
                    return s;
                }
                if (String.isNotBlank(teamNorm) && labelNorm.contains(teamNorm)) {
                    if (String.isBlank(queueNorm) || labelNorm.contains(queueNorm)) {
                        return s;
                    }
                }
                if (String.isNotBlank(queueNorm) && labelNorm.contains(queueNorm)) {
                    return s;
                }
            }
            if (out.routeViaRevertButton == true) {
                for (StageScreenRow s : screens) {
                    if (FEC_CaseBusinessService.REVERT.equalsIgnoreCase(s.actionButtonCode)) {
                        out.methodKey = FEC_CaseBusinessService.ROUTE_TO;
                        out.routeViaRevertButton = true;
                        return s;
                    }
                }
            }
            for (StageScreenRow s : screens) {
                if (FEC_CaseBusinessService.ROUTE_TO.equalsIgnoreCase(s.actionButtonCode)) {
                    return s;
                }
            }
            return null;
        }
        if (targetMethod == FEC_CaseBusinessService.UPDATEACTION) {
            String decisionNorm = normalizeToken(out.decision);
            for (StageScreenRow s : screens) {
                if (!FEC_CaseBusinessService.UPDATEACTION.equalsIgnoreCase(s.actionButtonCode)) {
                    continue;
                }
                String labelNorm = normalizeToken(buildScreenDisplayLabel(s));
                if (String.isNotBlank(decisionNorm) && labelNorm.contains(decisionNorm)) {
                    return s;
                }
            }
            for (StageScreenRow s : screens) {
                if (FEC_CaseBusinessService.UPDATEACTION.equalsIgnoreCase(s.actionButtonCode)) {
                    return s;
                }
            }
        }
        for (StageScreenRow s : screens) {
            if (targetMethod.equalsIgnoreCase(s.actionButtonCode)) {
                return s;
            }
        }
        return null;
    }

    private static String buildScreenDisplayLabel(StageScreenRow s) {
        if (s == null) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        if (FEC_CaseBusinessService.ROUTE_TO.equalsIgnoreCase(s.actionButtonCode)) {
            String label = String.isNotBlank(s.customLabel) ? s.customLabel.trim() : FEC_CaseBusinessService.ROUTE_TO;
            if (!label.toLowerCase().startsWith('route to')) {
                return 'Route to ' + label;
            }
            return label;
        }
        if (FEC_CaseBusinessService.UPDATEACTION.equalsIgnoreCase(s.actionButtonCode)) {
            String label = String.isNotBlank(s.customLabel) ? s.customLabel.trim() : FEC_ConstantCommon.STR_EMPTY;
            if (!label.toLowerCase().startsWith('update')) {
                return 'Update to ' + label;
            }
            return label;
        }
        if (String.isNotBlank(s.customLabel)) {
            return s.customLabel.trim();
        }
        if (String.isNotBlank(s.screenCode)) {
            return s.screenCode.trim();
        }
        return s.actionButtonCode;
    }

    private static String resolveMethodKeyFromMap(String raw) {
        if (String.isBlank(raw) || FEC_CaseBusinessService.METHOD_MAP == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (FEC_CaseBusinessService.METHOD_MAP.containsKey(trimmed)) {
            return trimmed;
        }
        for (String k : FEC_CaseBusinessService.METHOD_MAP.keySet()) {
            if (k != null && k.equalsIgnoreCase(trimmed)) {
                return k;
            }
        }
        return null;
    }

    private class ParsedPattern {
        public String methodKey;
        public String decision;
        public String routeTeamHint;
        public String routeQueueHint;
        public Boolean routeViaRevertButton;
        public Boolean revertPreferRevertedChange;
    }

    private static ParsedPattern parseExcelPattern(String raw) {
        ParsedPattern out = new ParsedPattern();
        out.routeViaRevertButton = false;
        out.revertPreferRevertedChange = false;
        if (String.isBlank(raw)) {
            return out;
        }
        String normalized = raw.trim().toLowerCase();
        if (normalized.startsWith('resolve')) {
            out.methodKey = FEC_CaseBusinessService.RESOLVE;
            return out;
        }
        if (normalized.startsWith('reject')) {
            out.methodKey = FEC_CaseBusinessService.REJECT;
            return out;
        }
        if (normalized.startsWith('cancel')) {
            out.methodKey = FEC_CaseBusinessService.CANCEL;
            return out;
        }
        if (normalized.startsWith('reopen')) {
            out.methodKey = FEC_CaseBusinessService.REOPEN;
            return out;
        }
        if (normalized.startsWith('recall')) {
            out.methodKey = FEC_CaseBusinessService.RECALL;
            return out;
        }
        if (normalized.startsWith('escalate')) {
            out.methodKey = FEC_CaseBusinessService.ESCALATE;
            return out;
        }
        if (normalized.contains('revert') && normalized.contains('team') && normalized.contains('queue')) {
            out.methodKey = FEC_CaseBusinessService.REVERT;
            out.revertPreferRevertedChange = true;
            return out;
        }
        if (normalized.startsWith('revert')) {
            out.methodKey = FEC_CaseBusinessService.REVERT;
            return out;
        }
        if (normalized.startsWith('update')) {
            out.methodKey = FEC_CaseBusinessService.UPDATEACTION;
            Integer pos = normalized.indexOf('to ');
            if (pos >= 0 && pos + 3 < raw.length()) {
                out.decision = raw.substring(pos + 3).trim();
            }
            return out;
        }
        if (normalized.startsWith('route to')) {
            out.methodKey = FEC_CaseBusinessService.ROUTE_TO;
            String tail = raw.substring(Math.min(raw.length(), 'Route to'.length())).trim();
            Integer dashPos = tail.indexOf('-');
            if (dashPos > -1) {
                String team = tail.substring(0, dashPos).trim();
                String queue = tail.substring(dashPos + 1).trim();
                out.routeTeamHint = String.isBlank(team) ? null : team;
                out.routeQueueHint = String.isBlank(queue) ? null : queue;
            } else if (String.isNotBlank(tail)) {
                out.routeQueueHint = tail;
            }
            return out;
        }
        return out;
    }

    private static String normalizeToken(String value) {
        return FEC_BatchCaseHandlingPicklistResolver.normalizeToken(value);
    }
}
