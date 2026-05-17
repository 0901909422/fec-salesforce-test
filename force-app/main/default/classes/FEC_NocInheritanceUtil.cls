/**
 * Cha/con NOC: cùng FEC_Product_Type__c; cha = ít field hierarchy hơn (nhiều null hơn).
 * So khớp prefix: field cha có giá trị thì phải trùng con (BP → Category → Sub Category → Sub Code).
 */
public without sharing class FEC_NocInheritanceUtil {

    public static Integer specificityScore(FEC_Nature_of_Case__c noc) {
        Integer score = 0;
        if (noc.FEC_Business_Process__c != null) {
            score++;
        }
        if (noc.FEC_Category__c != null) {
            score++;
        }
        if (noc.FEC_Sub_Category__c != null) {
            score++;
        }
        if (noc.FEC_Sub_Code__c != null) {
            score++;
        }
        return score;
    }

    /** Cha: Active, có Product Type, không có Sub Code (lá cha hoặc tầng trên). */
    public static Boolean isParentCandidate(FEC_Nature_of_Case__c noc) {
        return noc.FEC_Active__c == true
            && noc.FEC_Product_Type__c != null
            && noc.FEC_Sub_Code__c == null;
    }

    /** Con: Active, cùng Product Type, cụ thể hơn cha (ít null hơn). */
    public static Boolean isAncestorOf(FEC_Nature_of_Case__c parent, FEC_Nature_of_Case__c child) {
        if (parent.Id == child.Id) {
            return false;
        }
        if (parent.FEC_Product_Type__c != child.FEC_Product_Type__c) {
            return false;
        }
        if (specificityScore(parent) >= specificityScore(child)) {
            return false;
        }
        if (parent.FEC_Business_Process__c != null
            && parent.FEC_Business_Process__c != child.FEC_Business_Process__c) {
            return false;
        }
        if (parent.FEC_Category__c != null && parent.FEC_Category__c != child.FEC_Category__c) {
            return false;
        }
        if (parent.FEC_Sub_Category__c != null
            && parent.FEC_Sub_Category__c != child.FEC_Sub_Category__c) {
            return false;
        }
        return true;
    }

    /** Cha gần nhất: cùng PT, prefix khớp, điểm specificity cao nhất nhưng vẫn thấp hơn con. */
    public static FEC_Nature_of_Case__c findImmediateParent(
        FEC_Nature_of_Case__c child,
        List<FEC_Nature_of_Case__c> candidates
    ) {
        FEC_Nature_of_Case__c best = null;
        Integer bestScore = -1;
        for (FEC_Nature_of_Case__c p : candidates) {
            if (!isParentCandidate(p) || !isAncestorOf(p, child)) {
                continue;
            }
            Integer ps = specificityScore(p);
            if (ps > bestScore) {
                bestScore = ps;
                best = p;
            }
        }
        return best;
    }

    public static List<FEC_Nature_of_Case__c> findDescendants(
        FEC_Nature_of_Case__c parent,
        List<FEC_Nature_of_Case__c> candidates
    ) {
        List<FEC_Nature_of_Case__c> result = new List<FEC_Nature_of_Case__c>();
        for (FEC_Nature_of_Case__c c : candidates) {
            if (c.FEC_Active__c == true && isAncestorOf(parent, c)) {
                result.add(c);
            }
        }
        return result;
    }
}
