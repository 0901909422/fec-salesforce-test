public without sharing class FEC_RoutingHistTatSvc {
    private static final String FEC_BUSINESS_HOURS_NAME = 'FEC Business Hours';
    /** 1 "ngày" khi hiển thị TAT = 24 giờ (diffMs vẫn từ BusinessHours.diff). */
    private static final Integer FEC_TAT_DISPLAY_HOURS_PER_DAY = 24;

    private static Id cachedBusinessHoursId;
    private static Boolean businessHoursLookupDone = false;

    public static void applyBeforeSave(
        List<FEC_Routing_Action_History__c> newRows,
        Map<Id, FEC_Routing_Action_History__c> oldMap
    ) {
        if (newRows == null || newRows.isEmpty()) {
            return;
        }

        Set<Id> caseIds = new Set<Id>();
        Set<Id> assignmentIds = new Set<Id>();
        for (FEC_Routing_Action_History__c h : newRows) {
            if (h.FEC_Case__c != null) {
                caseIds.add(h.FEC_Case__c);
            }
            if (h.FEC_Assignment__c != null) {
                assignmentIds.add(h.FEC_Assignment__c);
            }
        }

        Map<Id, Case> caseById = caseIds.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                  SELECT Id, FEC_Case_Created_On__c, CreatedDate
                  FROM Case
                  WHERE Id IN :caseIds
              ]);

        Map<Id, FEC_Assignment__c> assignmentById = assignmentIds.isEmpty()
            ? new Map<Id, FEC_Assignment__c>()
            : new Map<Id, FEC_Assignment__c>([
                  SELECT Id, FEC_Manual__c, CreatedDate
                  FROM FEC_Assignment__c
                  WHERE Id IN :assignmentIds
              ]);

        applySubmittedOn(newRows, oldMap);

        Set<Id> updatingIds = oldMap != null ? oldMap.keySet() : new Set<Id>();
        List<FEC_Routing_Action_History__c> poolFromDb = caseIds.isEmpty()
            ? new List<FEC_Routing_Action_History__c>()
            : [
                  SELECT Id, FEC_Case__c, FEC_Assignment__c, FEC_Submitted_On__c, CreatedDate
                  FROM FEC_Routing_Action_History__c
                  WHERE FEC_Case__c IN :caseIds
                      AND FEC_Submitted_On__c != NULL
                      AND (Id NOT IN :updatingIds)
                  // bản đang update thay bằng bản trong newRows
              ];

        List<FEC_Routing_Action_History__c> pool = new List<FEC_Routing_Action_History__c>();
        pool.addAll(poolFromDb);
        pool.addAll(newRows);

        Id bhId = resolveBusinessHoursId();

        for (FEC_Routing_Action_History__c h : newRows) {
            if (oldMap != null) {
                FEC_Routing_Action_History__c prior = oldMap.get(h.Id);
                if (prior != null && !needsRecalc(h, prior)) {
                    continue;
                }
            }

            if (h.FEC_Case__c == null) {
                clearTatFields(h);
                continue;
            }

            Case c = caseById.get(h.FEC_Case__c);
            Datetime assignedOn = resolveAssignedOn(h, pool, caseById, assignmentById);
            h.FEC_Assigned_On__c = assignedOn;
            applyTatField(h, bhId, assignedOn);
        }

        Set<Id> caseIdsForFullTat = new Set<Id>();
        for (FEC_Routing_Action_History__c h : newRows) {
            if (h.FEC_Case__c != null) {
                caseIdsForFullTat.add(h.FEC_Case__c);
            }
        }
        if (!caseIdsForFullTat.isEmpty()) {
            FEC_CaseTatFullProcessSvc.syncCasesFromRoutingHistory(caseIdsForFullTat);
        }
    }

    /**
     * Code duoi nay cua hoangnm107
     * FEC_Submitted_On__c = thời điểm khởi tạo RAH (FEC_Date_Time__c ≈ CreatedDate).
     * Insert: offset giây trong batch để thứ tự strict &lt; khi suy Assigned On (TH1/TH2.1).
     */
    private static void applySubmittedOn(
        List<FEC_Routing_Action_History__c> newRows,
        Map<Id, FEC_Routing_Action_History__c> oldMap
    ) {
        Datetime base = System.now();
        Integer secOffset = 0;
        for (FEC_Routing_Action_History__c h : newRows) {
            if (h.FEC_Case__c == null) {
                continue;
            }
            if (oldMap != null && oldMap.containsKey(h.Id) && h.FEC_Submitted_On__c != null) {
                continue;
            }
            if (h.FEC_Submitted_On__c != null) {
                continue;
            }

            h.FEC_Submitted_On__c = h.FEC_Date_Time__c != null
                ? h.FEC_Date_Time__c
                : base.addSeconds(secOffset++);
        }
    }

    private static Datetime caseAnchorCreatedOn(Case c) {
        if (c == null) {
            return null;
        }
        if (c.FEC_Case_Created_On__c != null) {
            return c.FEC_Case_Created_On__c;
        }
        return c.CreatedDate;
    }

    private static void clearTatFields(FEC_Routing_Action_History__c h) {
        h.FEC_Assigned_On__c = null;
        h.FEC_TAT_by_Assignment__c = null;
    }

    private static void applyTatField(
        FEC_Routing_Action_History__c h,
        Id bhId,
        Datetime assignedOn
    ) {
        if (bhId == null || h.FEC_Submitted_On__c == null || assignedOn == null) {
            h.FEC_TAT_by_Assignment__c = null;
            return;
        }

        if (h.FEC_Submitted_On__c <= assignedOn) {
            h.FEC_TAT_by_Assignment__c = formatTatDisplay(0L);
            return;
        }

        Long diffMs = BusinessHours.diff(bhId, assignedOn, h.FEC_Submitted_On__c);
        if (diffMs == null || diffMs < 0) {
            h.FEC_TAT_by_Assignment__c = null;
            return;
        }

        h.FEC_TAT_by_Assignment__c = formatTatDisplay(diffMs);
    }

    private static Datetime resolveAssignedOn(
        FEC_Routing_Action_History__c h,
        List<FEC_Routing_Action_History__c> pool,
        Map<Id, Case> caseById,
        Map<Id, FEC_Assignment__c> assignmentById
    ) {
        Case c = caseById.get(h.FEC_Case__c);
        Datetime anchor = caseAnchorCreatedOn(c);

        if (h.FEC_Assignment__c == null) {
            return resolveTh1AssignedOn(h, pool, anchor);
        }
        return resolveTh2AssignedOn(h, pool, caseById, assignmentById, anchor);
    }

    /** TH1: FEC_Case__c <> null AND FEC_Assignment__c = null */
    private static Datetime resolveTh1AssignedOn(
        FEC_Routing_Action_History__c h,
        List<FEC_Routing_Action_History__c> pool,
        Datetime caseCreatedAnchor
    ) {
        if (h.FEC_Submitted_On__c == null) {
            return null;
        }
        FEC_Routing_Action_History__c prior = findBestPrior(
            pool,
            h,
            h.FEC_Case__c,
            null,
            h.FEC_Submitted_On__c,
            true,
            false
        );
        if (prior != null && prior.FEC_Submitted_On__c != null) {
            return prior.FEC_Submitted_On__c;
        }
        return caseCreatedAnchor;
    }

    /** TH2: FEC_Case__c <> null AND FEC_Assignment__c <> null */
    private static Datetime resolveTh2AssignedOn(
        FEC_Routing_Action_History__c h,
        List<FEC_Routing_Action_History__c> pool,
        Map<Id, Case> caseById,
        Map<Id, FEC_Assignment__c> assignmentById,
        Datetime caseCreatedAnchor
    ) {
        if (h.FEC_Submitted_On__c == null) {
            return null;
        }
        FEC_Assignment__c ass = assignmentById.get(h.FEC_Assignment__c);
        FEC_Routing_Action_History__c priorSameAssign = findBestPrior(
            pool,
            h,
            h.FEC_Case__c,
            h.FEC_Assignment__c,
            h.FEC_Submitted_On__c,
            true,
            false
        );
        if (priorSameAssign != null && priorSameAssign.FEC_Submitted_On__c != null) {
            return priorSameAssign.FEC_Submitted_On__c;
        }

        if (ass != null && ass.FEC_Manual__c == true) {
            FEC_Routing_Action_History__c priorCaseLevel = findBestPrior(
                pool,
                h,
                h.FEC_Case__c,
                null,
                h.FEC_Submitted_On__c,
                false,
                true
            );
            if (priorCaseLevel != null && priorCaseLevel.FEC_Submitted_On__c != null) {
                return priorCaseLevel.FEC_Submitted_On__c;
            }
        }

        return caseCreatedAnchor;
    }

    /**
     * @param strictLessSubmitted strict true: FEC_Submitted_On__c < current (TH1, TH2.1)
     *        strict false: <= (TH2.2.2)
     * @param requireAssignmentNull chỉ lấy RAH có FEC_Assignment__c = null (TH2.2.2)
     */
    private static FEC_Routing_Action_History__c findBestPrior(
        List<FEC_Routing_Action_History__c> pool,
        FEC_Routing_Action_History__c current,
        Id caseId,
        Id assignmentIdOrNull,
        Datetime currentSubmitted,
        Boolean strictLessSubmitted,
        Boolean requireAssignmentNull
    ) {
        FEC_Routing_Action_History__c best = null;
        for (FEC_Routing_Action_History__c cand : pool) {
            if (cand == current) {
                continue;
            }
            if (cand.FEC_Case__c != caseId) {
                continue;
            }
            if (requireAssignmentNull) {
                if (cand.FEC_Assignment__c != null) {
                    continue;
                }
            } else {
                if (assignmentIdOrNull == null) {
                    if (cand.FEC_Assignment__c != null) {
                        continue;
                    }
                } else if (cand.FEC_Assignment__c != assignmentIdOrNull) {
                    continue;
                }
            }
            if (cand.FEC_Submitted_On__c == null) {
                continue;
            }
            if (strictLessSubmitted) {
                if (!(cand.FEC_Submitted_On__c < currentSubmitted)) {
                    continue;
                }
            } else {
                if (!(cand.FEC_Submitted_On__c <= currentSubmitted)) {
                    continue;
                }
            }
            if (best == null) {
                best = cand;
                continue;
            }
            if (cand.FEC_Submitted_On__c > best.FEC_Submitted_On__c) {
                best = cand;
                continue;
            }
            if (cand.FEC_Submitted_On__c == best.FEC_Submitted_On__c && cand.CreatedDate > best.CreatedDate) {
                best = cand;
            }
        }
        return best;
    }

    private static Boolean needsRecalc(FEC_Routing_Action_History__c n, FEC_Routing_Action_History__c o) {
        return n.FEC_Submitted_On__c != o.FEC_Submitted_On__c
            || n.FEC_Assignment__c != o.FEC_Assignment__c
            || n.FEC_Case__c != o.FEC_Case__c;
    }

    private static Id resolveBusinessHoursId() {
        if (businessHoursLookupDone) {
            return cachedBusinessHoursId;
        }
        businessHoursLookupDone = true;

        List<BusinessHours> named = [
            SELECT Id
            FROM BusinessHours
            WHERE Name = :FEC_BUSINESS_HOURS_NAME AND IsActive = TRUE
            LIMIT 1
        ];
        if (!named.isEmpty()) {
            cachedBusinessHoursId = named[0].Id;
            return cachedBusinessHoursId;
        }

        List<BusinessHours> def = [
            SELECT Id FROM BusinessHours WHERE IsActive = TRUE AND IsDefault = TRUE LIMIT 1
        ];
        if (!def.isEmpty()) {
            cachedBusinessHoursId = def[0].Id;
        }
        return cachedBusinessHoursId;
    }

    /**
     * Hiển thị duration (diffMs từ BusinessHours.diff) dạng "N ngày N giờ N phút N giây".
     * 1 ngày hiển thị = 24 giờ.
     */
    public static String formatTatDisplay(Long diffMs) {
        return formatAsDaysHours(diffMs);
    }

    @TestVisible
    private static String formatAsDaysHours(Long diffMs) {
        if (diffMs == null || diffMs <= 0) {
            return '0 ngày 0 giờ 0 phút 0 giây';
        }

        Long totalSec = diffMs / 1000L;
        Long secPerDay = (Long)FEC_TAT_DISPLAY_HOURS_PER_DAY * 3600L;
        Long days = totalSec / secPerDay;
        Long rem = totalSec - days * secPerDay;
        Integer hours = (Integer)(rem / 3600L);
        Integer remAfterHours = (Integer)(rem - hours * 3600L);
        Integer minutes = remAfterHours / 60;
        Integer seconds = Math.mod(remAfterHours, 60);

        return days + ' ngày ' + hours + ' giờ ' + minutes + ' phút ' + seconds + ' giây';
    }
}