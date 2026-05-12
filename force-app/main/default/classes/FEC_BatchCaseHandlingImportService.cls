public without sharing class FEC_BatchCaseHandlingImportService {

    private static final Integer REMARK_MAX_LEN = 32768;

    public static Integer countFailedImportRows(List<FEC_BatchCaseHandlingImportRow> rows) {
        Integer n = 0;
        for (FEC_BatchCaseHandlingImportRow r : rows) {
            if (r != null && r.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed) {
                n += 1;
            }
        }
        return n;
    }

    public static List<FEC_BatchCaseHandlingImportRow> validateCaseHandlingImportRows(List<Object> inputRows, Boolean cofOrGsr) {
        List<FEC_BatchCaseHandlingImportRow> output = new List<FEC_BatchCaseHandlingImportRow>();
        List<String> searchKeys = new List<String>();
        for (Object rowObj : inputRows) {
            if (!(rowObj instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> row = (Map<String, Object>) rowObj;
            FEC_BatchCaseHandlingImportRow rr = new FEC_BatchCaseHandlingImportRow();
            rr.caseIdSearch = pickRowString(row, new List<String>{ 'caseidsearch', 'caseid' });
            rr.routingAction = pickRowString(row, new List<String>{ 'routingaction' });
            rr.inputtedRemarks = pickRowString(row, new List<String>{ 'inputtedremarks', 'remark', 'remarks' });
            rr.assignmentId = pickRowString(row, new List<String>{ 'assignmentid' });
            rr.assignmentRoutingAction = pickRowString(row, new List<String>{ 'assignmentroutingaction' });
            Boolean rowEmpty =
                String.isBlank(rr.caseIdSearch) &&
                String.isBlank(rr.routingAction) &&
                String.isBlank(rr.inputtedRemarks) &&
                String.isBlank(rr.assignmentId) &&
                String.isBlank(rr.assignmentRoutingAction);
            if (rowEmpty) {
                continue;
            }
            rr.recordId = FEC_ConstantCommon.STR_EMPTY;
            rr.status = System.Label.FEC_Operation_Success;
            rr.errors = FEC_ConstantCommon.STR_EMPTY;
            output.add(rr);
            if (String.isNotBlank(rr.caseIdSearch)) {
                searchKeys.add(rr.caseIdSearch);
            }
        }

        Map<String, Case> caseBySearch = new Map<String, Case>();
        if (!searchKeys.isEmpty()) {
            for (Case c : [
                SELECT Id, IsClosed, FEC_ID_Search__c
                FROM Case
                WHERE FEC_ID_Search__c IN :searchKeys
                LIMIT 5000
            ]) {
                if (c.FEC_ID_Search__c != null) {
                    caseBySearch.put(c.FEC_ID_Search__c, c);
                }
            }
        }

        Set<Id> assignmentIdSet = new Set<Id>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            if (!cofOrGsr || String.isBlank(rr.assignmentId)) {
                continue;
            }
            try {
                assignmentIdSet.add(Id.valueOf(rr.assignmentId.trim()));
            } catch (Exception e) {
            }
        }
        Map<Id, FEC_Assignment__c> assignmentById = new Map<Id, FEC_Assignment__c>();
        if (!assignmentIdSet.isEmpty()) {
            assignmentById.putAll([
                SELECT Id, FEC_Case__c, FEC_Assignment_Status__c
                FROM FEC_Assignment__c
                WHERE Id IN :assignmentIdSet
            ]);
        }

        Set<String> seenCaseSearch = new Set<String>();
        for (FEC_BatchCaseHandlingImportRow rr : output) {
            List<String> errs = new List<String>();
            if (String.isBlank(rr.caseIdSearch)) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Case_Id);
            }
            Case matched = String.isNotBlank(rr.caseIdSearch) ? caseBySearch.get(rr.caseIdSearch) : null;
            if (String.isNotBlank(rr.caseIdSearch) && matched == null) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Id_Not_Found);
            } else if (matched != null && matched.IsClosed) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Case_Closed);
            }
            if (String.isNotBlank(rr.caseIdSearch)) {
                if (seenCaseSearch.contains(rr.caseIdSearch)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Duplicate_Case_Id);
                } else {
                    seenCaseSearch.add(rr.caseIdSearch);
                }
            }

            if (cofOrGsr) {
                Boolean hasAssignment = String.isNotBlank(rr.assignmentId);
                if (hasAssignment) {
                    Id asgId;
                    try {
                        asgId = Id.valueOf(rr.assignmentId.trim());
                    } catch (Exception e) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                        asgId = null;
                    }
                    if (asgId != null) {
                        FEC_Assignment__c asg = assignmentById.get(asgId);
                        if (asg == null) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                        } else if (matched != null && asg.FEC_Case__c != matched.Id) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Id_Not_Found);
                        } else if (String.isNotBlank(asg.FEC_Assignment_Status__c) && asg.FEC_Assignment_Status__c.startsWith('Resolved-')) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Closed);
                        }
                    }
                    if (String.isNotBlank(rr.routingAction) && String.isNotBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Both_Routing_Actions);
                    }
                    if (String.isBlank(rr.routingAction) && String.isBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Or_Assignment_Routing);
                    }
                    if (String.isNotBlank(rr.routingAction)) {
                        String caseMethod = resolveRoutingMethodKey(rr.routingAction);
                        if (caseMethod == null) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                        } else if (!isResolvedOrRejectCaseRouting(rr.routingAction)) {
                            errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Resolve_Only);
                        }
                    }
                    if (String.isNotBlank(rr.assignmentRoutingAction) && resolveRoutingMethodKey(rr.assignmentRoutingAction) == null) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid);
                    }
                } else {
                    if (String.isBlank(rr.routingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action);
                    } else if (resolveRoutingMethodKey(rr.routingAction) == null) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                    }
                    if (String.isNotBlank(rr.assignmentRoutingAction)) {
                        errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Without_Assignment_Id);
                    }
                }
            } else {
                if (String.isNotBlank(rr.assignmentRoutingAction)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_No_Assignment_Routing_For_Process);
                }
                if (String.isNotBlank(rr.assignmentId)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_No_Assignment_Id_For_Process);
                }
                if (String.isBlank(rr.routingAction)) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Routing_Action);
                } else if (resolveRoutingMethodKey(rr.routingAction) == null) {
                    errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid);
                }
            }

            if (String.isBlank(rr.inputtedRemarks)) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Missing_Remark);
            } else if (rr.inputtedRemarks.length() > REMARK_MAX_LEN) {
                errs.add(System.Label.FEC_Batch_Case_Handling_Import_Err_Remark_Too_Long);
            }

            if (!errs.isEmpty()) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = String.join(errs, ' ');
            } else {
                rr.recordId = matched == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(matched.Id);
            }
        }
        return output;
    }

    public static void applyCaseHandlingUpdates(List<FEC_BatchCaseHandlingImportRow> rows, Boolean cofOrGsr) {
        if (rows == null || rows.isEmpty()) {
            return;
        }
        for (FEC_BatchCaseHandlingImportRow rr : rows) {
            if (rr == null || rr.status == System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed || String.isBlank(rr.recordId)) {
                continue;
            }
            Id caseId;
            try {
                caseId = Id.valueOf(rr.recordId);
            } catch (Exception e) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(rr.errors, System.Label.FEC_Batch_Case_Handling_Import_Err_Record_Id_Invalid);
                continue;
            }
            String actionLabel = rr.routingAction;
            if (cofOrGsr && String.isBlank(actionLabel)) {
                actionLabel = rr.assignmentRoutingAction;
            }
            String methodKey = resolveRoutingMethodKey(actionLabel);
            if (String.isBlank(methodKey)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    cofOrGsr
                        ? System.Label.FEC_Batch_Case_Handling_Import_Err_Assignment_Routing_Invalid
                        : System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Action_Invalid
                );
                continue;
            }
            if (routingActionRequiresExtraParams(methodKey)) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(
                    rr.errors,
                    System.Label.FEC_Batch_Case_Handling_Import_Err_Routing_Requires_Params
                );
                continue;
            }
            try {
                FEC_CaseBusinessService.run(methodKey, new Map<String, String>{ 'caseId' => String.valueOf(caseId) });
            } catch (Exception ex) {
                rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                rr.errors = appendError(rr.errors, ex.getMessage());
                continue;
            }
            if (String.isNotBlank(rr.inputtedRemarks)) {
                try {
                    FEC_CaseRemarkController.createRemark(rr.inputtedRemarks, String.valueOf(caseId), null);
                } catch (Exception ex) {
                    rr.status = System.Label.FEC_Batch_Case_Handling_Import_Row_Status_Failed;
                    rr.errors = appendError(rr.errors, ex.getMessage());
                }
            }
        }
    }

    public static Boolean isCofOrGsrTemplate(String templateName) {
        if (String.isBlank(templateName)) {
            return false;
        }
        String t = templateName.toLowerCase();
        return t.contains('cof') || t.contains('gsr');
    }

    private static String resolveRoutingMethodKey(String raw) {
        if (String.isBlank(raw)) {
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

    private static Boolean routingActionRequiresExtraParams(String methodKey) {
        if (String.isBlank(methodKey)) {
            return true;
        }
        return methodKey == FEC_CaseBusinessService.ROUTE_TO ||
            methodKey == FEC_CaseBusinessService.UPDATEACTION ||
            methodKey == FEC_CaseBusinessService.TRANSFER ||
            methodKey == FEC_CaseBusinessService.REVERT;
    }

    private static Boolean isResolvedOrRejectCaseRouting(String routingLabel) {
        String k = resolveRoutingMethodKey(routingLabel);
        if (String.isBlank(k)) {
            return false;
        }
        return k == FEC_CaseBusinessService.RESOLVE || k == FEC_CaseBusinessService.REJECT;
    }

    private static String pickRowString(Map<String, Object> row, List<String> normalizedKeys) {
        Map<String, String> flat = new Map<String, String>();
        for (String k : row.keySet()) {
            String nk = k == null ? FEC_ConstantCommon.STR_EMPTY : k.replaceAll('\\s+', '').toLowerCase();
            if (String.isNotBlank(nk)) {
                Object v = row.get(k);
                flat.put(nk, v == null ? FEC_ConstantCommon.STR_EMPTY : String.valueOf(v).trim());
            }
        }
        for (String want : normalizedKeys) {
            if (flat.containsKey(want)) {
                return flat.get(want);
            }
        }
        return FEC_ConstantCommon.STR_EMPTY;
    }

    private static String appendError(String current, String incoming) {
        if (String.isBlank(incoming)) {
            return current;
        }
        if (String.isBlank(current)) {
            return incoming;
        }
        return current + ' ' + incoming;
    }
}