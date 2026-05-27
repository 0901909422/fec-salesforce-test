/**
 * Map FEC_Sales_Channel__c / FEC_Sales_Sub_Channel__c theo bảng II (STT 1–35)
 * đọc từ FEC_Sales_Logic__c (FEC_Sequence__c = STT ưu tiên).
 */
public with sharing class FEC_SalesChannelFromApplicationService {

    private static final String AR_CC_GROUP = 'AR;DE;SG;ZP;HS';
    private static final String RULE34_TSA_TOKENS =
        'TSA13;TSA20;TSA27;TSA38;TSA41;TSA48;TSA54;TSA55;TSA80;TSA90;TSA37';
    private static final String DEFAULT_CHANNEL = '-';
    private static final String DEFAULT_SUB_CHANNEL = '-';

    private static final Set<String> SGO_TSA_EXCLUDE_PREFIXES = new Set<String>{
        'TSA13', 'TSA20', 'TSA27', 'TSA38', 'TSA41', 'TSA48', 'TSA54', 'TSA55', 'TSA80', 'TSA90'
    };

    private static final List<String> TP_DSA_PREFIXES = new List<String>{
        'TSA13', 'TSA20', 'TSA27', 'TSA38', 'TSA41', 'TSA48', 'TSA54', 'TSA55', 'TSA80', 'TSA90', 'TSA37'
    };

    // Bảng II STT 34: prefix TSA37 trừ các mã sau (không map rule 34 / TSA chung)
    private static final Set<String> TSA37_BLOCKED_CODES = new Set<String>{
        'TSA37009', 'TSA37010', 'TSA37011', 'TSA37015'
    };

    private static List<FEC_Sales_Logic__c> cachedRules;

    private enum RuleKind {
        CC_ONLY,
        KF_TSA_WHEN_DSA_BLANK,
        SGO,
        TP,
        TSA_RULE34,
        TSA_GENERAL,
        STANDARD_STEP2
    }

    public class SalesChannelResult {
        public String channel;
        public String subChannel;
    }

    public static void syncCustomerHistoryFromSalesLogic(List<FEC_Customer_History__c> customerHistoryRows) {
        if (customerHistoryRows == null || customerHistoryRows.isEmpty()) {
            return;
        }
        if (!Schema.sObjectType.FEC_Customer_History__c.isUpdateable()) {
            return;
        }
        if (!FEC_Customer_History__c.FEC_Sales_Channel__c.getDescribe().isUpdateable()
            || !FEC_Customer_History__c.FEC_Sales_Sub_Channel__c.getDescribe().isUpdateable()) {
            return;
        }
        List<FEC_Customer_History__c> toUpdate = new List<FEC_Customer_History__c>();
        for (FEC_Customer_History__c ch : customerHistoryRows) {
            if (ch == null || ch.Id == null) {
                continue;
            }
            SalesChannelResult resolved = resolve(ch.FEC_CC_Code__c, ch.FEC_DSA_Code__c, ch.FEC_TSA_Code__c);
            toUpdate.add(new FEC_Customer_History__c(
                Id = ch.Id,
                FEC_Sales_Channel__c = resolved != null ? resolved.channel : null,
                FEC_Sales_Sub_Channel__c = resolved != null ? resolved.subChannel : null
            ));
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    @TestVisible
    static SalesChannelResult resolveForTest(String cc, String dsa, String tsa) {
        return resolve(cc, dsa, tsa);
    }

    @TestVisible
    static void clearRulesCacheForTest() {
        cachedRules = null;
    }

    public static SalesChannelResult resolveSalesChannelFromApplicationCodes(String ccCode, String dsaCode, String tsaCode) {
        return resolve(ccCode, dsaCode, tsaCode);
    }

    private static SalesChannelResult resolve(String cc, String dsa, String tsa) {
        String c = norm(cc);
        String d = norm(dsa);
        String t = norm(tsa);

        for (FEC_Sales_Logic__c logic : loadRulesOrdered()) {
            if (logic == null || isDefaultRule(logic)) {
                continue;
            }
            if (ruleMatches(logic, c, d, t)) {
                return resultFromLogic(logic);
            }
        }

        return defaultResult();
    }

    private static List<FEC_Sales_Logic__c> loadRulesOrdered() {
        if (cachedRules == null) {
            List<FEC_Sales_Logic__c> rows = FEC_SalesLogicSelector.selectAllOrdered();
            rows.sort(new SalesLogicSequenceComparator());
            cachedRules = rows;
        }
        return cachedRules;
    }

    private static Boolean isDefaultRule(FEC_Sales_Logic__c logic) {
        String ch = norm(logic.FEC_Sales_Channel__c);
        return ch == DEFAULT_CHANNEL;
    }

    private static SalesChannelResult resultFromLogic(FEC_Sales_Logic__c logic) {
        SalesChannelResult r = new SalesChannelResult();
        String ch = norm(logic.FEC_Sales_Channel__c);
        String sub = norm(logic.FEC_Sales_Sub_Channel__c);
        r.channel = String.isBlank(ch) ? null : ch;
        r.subChannel = String.isBlank(sub) ? null : sub;
        return r;
    }

    private static SalesChannelResult defaultResult() {
        return pair(DEFAULT_CHANNEL, DEFAULT_SUB_CHANNEL);
    }

    private static Boolean ruleMatches(FEC_Sales_Logic__c logic, String c, String d, String t) {
        RuleKind kind = classifyRule(logic);
        if (kind == RuleKind.CC_ONLY) {
            return listMatch(c, norm(logic.FEC_CC_Code__c));
        }
        if (!step2CcMatches(c, logic)) {
            return false;
        }
        if (kind == RuleKind.KF_TSA_WHEN_DSA_BLANK) {
            return String.isBlank(d) && listMatch(t, patternForStep2(logic));
        }
        if (!step2PatternMatches(logic, d, t, kind)) {
            return false;
        }
        if (kind == RuleKind.SGO && sgoTsaExcluded(d, t)) {
            return false;
        }
        if (kind == RuleKind.TP && tpBlocked(d, t)) {
            return false;
        }
        if (kind == RuleKind.TSA_RULE34 && !arRule34Match(d, t)) {
            return false;
        }
        if (kind == RuleKind.TSA_GENERAL && !arGeneralTsaMatch(d, t)) {
            return false;
        }
        return true;
    }

    private static RuleKind classifyRule(FEC_Sales_Logic__c logic) {
        String cc = norm(logic.FEC_CC_Code__c);
        String dsa = norm(logic.FEC_DSA_Code__c);
        String tsa = norm(logic.FEC_TSA_Code__c);

        if (String.isBlank(dsa) && String.isBlank(tsa) && String.isNotBlank(cc)) {
            return RuleKind.CC_ONLY;
        }
        if (isKfRule(dsa, tsa)) {
            return RuleKind.KF_TSA_WHEN_DSA_BLANK;
        }
        if (listMatch(dsa, 'SGO') || listMatch(tsa, 'SGO')) {
            return RuleKind.SGO;
        }
        if (listMatch(dsa, 'TP') || listMatch(tsa, 'TP')) {
            return RuleKind.TP;
        }
        if (listMatch(dsa, RULE34_TSA_TOKENS) || listMatch(tsa, RULE34_TSA_TOKENS)) {
            return RuleKind.TSA_RULE34;
        }
        if (isGeneralTsaRule(dsa, tsa)) {
            return RuleKind.TSA_GENERAL;
        }
        return RuleKind.STANDARD_STEP2;
    }

    private static Boolean isKfRule(String dsa, String tsa) {
        return listMatch(dsa, 'KF') && listMatch(tsa, 'KF');
    }

    private static Boolean isGeneralTsaRule(String dsa, String tsa) {
        if (String.isNotBlank(dsa) && String.isBlank(tsa)) {
            return dsa.equalsIgnoreCase('TSA');
        }
        if (String.isBlank(dsa) && String.isNotBlank(tsa)) {
            return tsa.equalsIgnoreCase('TSA');
        }
        return dsa.equalsIgnoreCase('TSA') && tsa.equalsIgnoreCase('TSA');
    }

    private static Boolean step2PatternMatches(FEC_Sales_Logic__c logic, String d, String t, RuleKind kind) {
        if (kind == RuleKind.TSA_RULE34 || kind == RuleKind.TSA_GENERAL) {
            return true;
        }
        return arPatternMatch(d, t, patternForStep2(logic));
    }

    private static String patternForStep2(FEC_Sales_Logic__c logic) {
        String dsa = norm(logic.FEC_DSA_Code__c);
        if (String.isNotBlank(dsa)) {
            return dsa;
        }
        return norm(logic.FEC_TSA_Code__c);
    }

    private static String norm(String v) {
        return v == null ? '' : v.trim();
    }

    private static String codeForArRules(String d, String t) {
        return String.isNotBlank(d) ? d : t;
    }

    private static Boolean arPatternMatch(String d, String t, String semicolonPatterns) {
        return listMatch(codeForArRules(d, t), semicolonPatterns);
    }

    private static Boolean listMatch(String val, String semicolonPatterns) {
        if (String.isBlank(semicolonPatterns) || String.isBlank(val)) {
            return false;
        }
        String vu = val.toUpperCase();
        for (String raw : semicolonPatterns.split(';')) {
            String tok = raw == null ? '' : raw.trim();
            if (String.isBlank(tok)) {
                continue;
            }
            String tu = tok.toUpperCase();
            if (vu.equals(tu) || vu.startsWith(tu)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean step2EligibleCc(String cc) {
        if (String.isBlank(cc)) {
            return true;
        }
        return listMatch(cc, AR_CC_GROUP);
    }

    private static Boolean step2CcMatches(String c, FEC_Sales_Logic__c logic) {
        if (!step2EligibleCc(c)) {
            return false;
        }
        String ruleCc = norm(logic.FEC_CC_Code__c);
        if (String.isBlank(c) || String.isBlank(ruleCc)) {
            return true;
        }
        return listMatch(c, ruleCc);
    }

    private static Boolean sgoTsaExcluded(String dsa, String tsa) {
        if (String.isBlank(dsa) || String.isBlank(tsa)) {
            return false;
        }
        String du = dsa.toUpperCase();
        if (!du.startsWith('TSA')) {
            return false;
        }
        String tu = tsa.toUpperCase();
        for (String p : SGO_TSA_EXCLUDE_PREFIXES) {
            if (tu.equals(p) || tu.startsWith(p)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean tpBlocked(String dsa, String tsa) {
        if (String.isBlank(dsa)) {
            return false;
        }
        String du = dsa.toUpperCase();
        Boolean dsaHit = false;
        for (String p : TP_DSA_PREFIXES) {
            String pu = p.toUpperCase();
            if (du.equals(pu) || du.startsWith(pu)) {
                dsaHit = true;
                break;
            }
        }
        if (!dsaHit || String.isBlank(tsa)) {
            return false;
        }
        return isBlockedTsa37Code(tsa);
    }

    private static Boolean arRule34Match(String d, String t) {
        String code = codeForArRules(d, t);
        if (!listMatch(code, RULE34_TSA_TOKENS)) {
            return false;
        }
        if (listMatch(code, 'TSA37') && isBlockedTsa37Code(code)) {
            return false;
        }
        return true;
    }

    private static Boolean isBlockedTsa37Code(String code) {
        if (String.isBlank(code)) {
            return false;
        }
        String cu = code.toUpperCase();
        for (String blocked : TSA37_BLOCKED_CODES) {
            if (cu.equals(blocked) || cu.startsWith(blocked)) {
                return true;
            }
        }
        return false;
    }

    private static Boolean arGeneralTsaMatch(String d, String t) {
        String code = codeForArRules(d, t);
        if (String.isBlank(code)) {
            return false;
        }
        String cu = code.toUpperCase();
        if (!cu.startsWith('TSA')) {
            return false;
        }
        if (isBlockedTsa37Code(code)) {
            return false;
        }
        for (String p : SGO_TSA_EXCLUDE_PREFIXES) {
            String pu = p.toUpperCase();
            if (cu.equals(pu) || cu.startsWith(pu)) {
                return false;
            }
        }
        return true;
    }

    private static SalesChannelResult pair(String ch, String sub) {
        SalesChannelResult r = new SalesChannelResult();
        r.channel = ch;
        r.subChannel = sub;
        return r;
    }

    private class SalesLogicSequenceComparator implements Comparator<FEC_Sales_Logic__c> {
        public Integer compare(FEC_Sales_Logic__c a, FEC_Sales_Logic__c b) {
            Integer sa = sequenceOf(a);
            Integer sb = sequenceOf(b);
            if (sa == sb) {
                String na = a != null && a.Name != null ? a.Name : '';
                String nb = b != null && b.Name != null ? b.Name : '';
                return na.compareTo(nb);
            }
            return sa < sb ? -1 : 1;
        }

        private Integer sequenceOf(FEC_Sales_Logic__c logic) {
            if (logic == null) {
                return 99999;
            }
            if (logic.FEC_Sequence__c != null) {
                return logic.FEC_Sequence__c.intValue();
            }
            String nm = logic.Name;
            if (String.isNotBlank(nm) && nm.startsWith('S-')) {
                try {
                    return Integer.valueOf(nm.substring(2));
                } catch (Exception e) {
                    return 99999;
                }
            }
            return 99999;
        }
    }
}
