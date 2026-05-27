/**
 * Đồng bộ FEC_Sales_Channel__c / FEC_Sales_Sub_Channel__c trên FEC_Customer_History__c
 * theo FEC_Sales_Logic__c (mã CC/DSA/TSA) hoặc rule legacy cho export batch.
 */
public with sharing class FEC_SalesChannelFromApplicationService {

    private static final Set<String> SGO_TSA_EXCLUDE_PREFIXES = new Set<String>{
        'TSA13', 'TSA20', 'TSA27', 'TSA38', 'TSA41', 'TSA48', 'TSA54', 'TSA55', 'TSA80', 'TSA90'
    };

    private static final List<String> TP_DSA_PREFIXES = new List<String>{
        'TSA13', 'TSA20', 'TSA27', 'TSA38', 'TSA41', 'TSA48', 'TSA54', 'TSA55', 'TSA80', 'TSA90', 'TSA37'
    };

    private static final Set<String> TP_TSA_EXCLUDE_EXACT = new Set<String>{
        'TSA37009', 'TSA37010', 'TSA37011', 'TSA37015'
    };

    private static final String RULE34_TSA_TOKENS =
        'TSA13;TSA20;TSA27;TSA38;TSA41;TSA48;TSA54;TSA55;TSA80;TSA90;TSA37';

    public class SalesChannelResult {
        public String channel;
        public String subChannel;
    }

    /**
     * Cập nhật FEC_Sales_Channel__c / FEC_Sales_Sub_Channel__c trên Customer History
     * bằng cách so khớp FEC_CC_Code__c, FEC_DSA_Code__c, FEC_TSA_Code__c với FEC_Sales_Logic__c.
     */
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
        if (!Schema.sObjectType.FEC_Sales_Logic__c.isAccessible()) {
            return;
        }

        Map<String, FEC_Sales_Logic__c> logicByKey = buildSalesLogicByCodeKey();
        List<FEC_Customer_History__c> toUpdate = new List<FEC_Customer_History__c>();
        for (FEC_Customer_History__c ch : customerHistoryRows) {
            if (ch == null || ch.Id == null) {
                continue;
            }
            FEC_Sales_Logic__c logic = logicByKey.get(salesLogicKey(ch.FEC_CC_Code__c, ch.FEC_DSA_Code__c, ch.FEC_TSA_Code__c));
            toUpdate.add(new FEC_Customer_History__c(
                Id = ch.Id,
                FEC_Sales_Channel__c = logic != null ? logic.FEC_Sales_Channel__c : null,
                FEC_Sales_Sub_Channel__c = logic != null ? logic.FEC_Sales_Sub_Channel__c : null
            ));
        }

        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
            } catch (DmlException e) {
                throw e;
            }
        }
    }

    private static Map<String, FEC_Sales_Logic__c> buildSalesLogicByCodeKey() {
        Map<String, FEC_Sales_Logic__c> logicByKey = new Map<String, FEC_Sales_Logic__c>();
        for (FEC_Sales_Logic__c logic : [
            SELECT FEC_CC_Code__c, FEC_DSA_Code__c, FEC_TSA_Code__c, FEC_Sales_Channel__c, FEC_Sales_Sub_Channel__c
            FROM FEC_Sales_Logic__c
        ]) {
            String key = salesLogicKey(logic.FEC_CC_Code__c, logic.FEC_DSA_Code__c, logic.FEC_TSA_Code__c);
            if (!logicByKey.containsKey(key)) {
                logicByKey.put(key, logic);
            }
        }
        return logicByKey;
    }

    private static String salesLogicKey(String cc, String dsa, String tsa) {
        return norm(cc) + '\u0001' + norm(dsa) + '\u0001' + norm(tsa);
    }

    @TestVisible
    static SalesChannelResult resolveForTest(String cc, String dsa, String tsa) {
        return resolve(cc, dsa, tsa);
    }

    public static SalesChannelResult resolveSalesChannelFromApplicationCodes(String ccCode, String dsaCode, String tsaCode) {
        return resolve(ccCode, dsaCode, tsaCode);
    }

    private static SalesChannelResult resolve(String cc, String dsa, String tsa) {
        String c = norm(cc);
        String d = norm(dsa);
        String t = norm(tsa);

        SalesChannelResult out;

        out = tryRules1Through35(c, d, t);
        if (out != null) {
            return out;
        }

        out = new SalesChannelResult();
        out.channel = '-';
        out.subChannel = '-';
        return out;
    }

    private static String norm(String v) {
        return v == null ? '' : v.trim();
    }

    private static Boolean listMatch(String val, String semicolonPatterns) {
        if (String.isBlank(semicolonPatterns)) {
            return false;
        }
        if (String.isBlank(val)) {
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

    private static Boolean listMatchOr(String val, String semicolonPatterns) {
        return listMatch(val, semicolonPatterns);
    }

    private static Boolean inArDeSgZpHs(String cc) {
        return listMatch(cc, 'AR;DE;SG;ZP;HS');
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
        if (!dsaHit) {
            return false;
        }
        if (String.isBlank(tsa)) {
            return false;
        }
        String tu = tsa.toUpperCase();
        for (String ex : TP_TSA_EXCLUDE_EXACT) {
            if (tu.equals(ex) || tu.startsWith(ex)) {
                return true;
            }
        }
        return false;
    }

    private static SalesChannelResult pair(String ch, String sub) {
        SalesChannelResult r = new SalesChannelResult();
        r.channel = ch;
        r.subChannel = sub;
        return r;
    }

    /**
     * Thứ tự ưu tiên theo STT bảng II; rule TSA cụ thể (STT 34) xét trước rule TSA chung (STT 29).
     */
    private static SalesChannelResult tryRules1Through35(String c, String d, String t) {
        if (listMatch(c, 'CC')) {
            return pair('POS', 'POS_CC');
        }
        if (listMatch(c, 'KI')) {
            return pair('THIRD PARTY', null);
        }
        if (listMatch(c, 'KS;KFE')) {
            return pair('THIRD PARTY', 'SMARTNET_KIOSK');
        }
        if (listMatch(c, 'KP')) {
            return pair('THIRD PARTY', 'SMARTNET_TELEX');
        }

        if (inArDeSgZpHs(c) && (listMatchOr(d, 'CC;CE') || listMatchOr(t, 'CC;CE'))) {
            return pair('POS', 'POS_CC');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'CSD;MW') && listMatch(t, 'CSD;MW')) {
            return pair('POS', 'SALESMAN');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'RB') && listMatch(t, 'RB')) {
            return pair('THIRD PARTY', 'DIAMONDSTAR');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'DMS;DMH') && listMatch(t, 'DMS;DMH')) {
            return pair('THIRD PARTY', 'DIAMONDSTAR');
        }
        if (inArDeSgZpHs(c) && String.isNotBlank(d) && listMatch(d, 'DMD;DMC') && listMatch(t, 'DMD;DMC')) {
            return pair('THIRD PARTY', 'DIAMONDSTAR');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TTU') && listMatch(t, 'TTU')) {
            return pair('THIRD PARTY', 'THIENTU');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'DG') && listMatch(t, 'DG')) {
            return pair('THIRD PARTY', 'DIGITEL');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'CCT') && listMatch(t, 'CCT')) {
            return pair('THIRD PARTY', 'CONCENTRIX');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'SGO') && listMatch(t, 'SGO') && !sgoTsaExcluded(d, t)) {
            return pair('THIRD PARTY', 'SAIGONBPO');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'CL') && listMatch(t, 'CL')) {
            return pair('THIRD PARTY', 'CALLUS');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TP') && listMatch(t, 'TP') && !tpBlocked(d, t)) {
            return pair('THIRD PARTY', 'THINHPHAT');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'KP;SN') && listMatch(t, 'KP;SN')) {
            return pair('THIRD PARTY', 'SMARTNET_TELEX');
        }
        if (inArDeSgZpHs(c) && String.isBlank(d) && listMatch(t, 'KF')) {
            return pair('THIRD PARTY', null);
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'KS;KFE') && listMatch(t, 'KS;KFE')) {
            return pair('THIRD PARTY', 'SMARTNET_KIOSK');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'SM') && listMatch(t, 'SM') && String.isNotBlank(t)) {
            return pair('THIRD PARTY', null);
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'DSAT') && listMatch(t, 'DSAT')) {
            return pair('DS_IH', 'COURIER');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'DSA') && listMatch(t, 'DSA')) {
            return pair('DS_IH', 'DSA');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'DA') && listMatch(t, 'DA')) {
            return pair('DS_IH', 'DSA');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'CSE;DSP') && listMatch(t, 'CSE;DSP')) {
            return pair(null, null);
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'KV;VN;DPC') && listMatch(t, 'KV;VN;DPC')) {
            return pair('VNPOST', 'VNPOST');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TSAD;TSAE') && listMatch(t, 'TSAD;TSAE')) {
            return pair('XS_IH', 'XSELL_CRC');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'IO') && listMatch(t, 'IO')) {
            return pair('XS_IH', 'XSELL_PL');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TX') && listMatch(t, 'TX')) {
            return pair('XS_IH', 'XSELL_PL');
        }

        if (inArDeSgZpHs(c) && listMatch(d, RULE34_TSA_TOKENS) && listMatch(t, RULE34_TSA_TOKENS)) {
            return pair('LG_IH', 'LG_NTB');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TLP') && listMatch(t, 'TLP')) {
            return pair('LG_IH', 'LG_NTB');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TSAM') && listMatch(t, 'TSAM')) {
            return pair('LG_IH', 'LG_NTB');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TSAT') && listMatch(t, 'TSAT')) {
            return pair('LG_IH', 'LG_NTB');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TG') && listMatch(t, 'TG')) {
            return pair('LG_IH', 'LG_NTB');
        }
        if (inArDeSgZpHs(c) && listMatch(d, 'TSA') && listMatch(t, 'TSA')) {
            return pair('XS_IH', 'XSELL_PL');
        }

        return null;
    }
}
