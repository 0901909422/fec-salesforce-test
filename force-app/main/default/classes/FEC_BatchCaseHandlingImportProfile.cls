/**
 * Import scope and field requirements aligned with Design - Batch Processing.xlsx
 * (Logic xử lý Import + Template list).
 */
public with sharing class FEC_BatchCaseHandlingImportProfile {

    public static final String FIELD_PROFILE_NONE = 'NONE';
    public static final String FIELD_PROFILE_D2C = 'D2C';
    public static final String FIELD_PROFILE_CS_SUPPORT = 'CS_SUPPORT';
    private static final String ERR_IMPORT_OUT_OF_SCOPE =
        'Case không thuộc phạm vi import cho quy trình {0} và nhóm người dùng {1}.';

    public class ImportScope {
        public Boolean allowed;
        public String fieldProfile;
        public String errorMessage;

        public ImportScope() {
            allowed = true;
            fieldProfile = FIELD_PROFILE_NONE;
            errorMessage = FEC_ConstantCommon.STR_EMPTY;
        }
    }

    public static ImportScope resolveForCase(String businessProcessCode, String userGroup) {
        ImportScope scope = new ImportScope();
        if (String.isBlank(businessProcessCode)) {
            return scope;
        }
        String prefix = FEC_BatchCaseHandlingTemplateHelper.mapBusinessProcessToTemplatePrefix(
            businessProcessCode
        );
        if (String.isBlank(prefix)) {
            return scope;
        }
        List<String> suffixes = FEC_BatchCaseHandlingTemplateHelper.mapUserGroupToTemplateSuffixes(
            businessProcessCode,
            userGroup
        );
        if (suffixes == null || suffixes.isEmpty()) {
            scope.allowed = false;
            scope.errorMessage = buildScopeErrorMessage(businessProcessCode, userGroup);
            return scope;
        }
        String suffixNorm = suffixes[0].trim().toUpperCase();
        if (suffixNorm == 'CSD2C') {
            scope.fieldProfile = FIELD_PROFILE_D2C;
        } else if (
            suffixNorm == 'CSSUPPORT' ||
            suffixNorm == 'CSCUSTOMERCARE' ||
            suffixNorm == 'OTHERCS'
        ) {
            scope.fieldProfile = FIELD_PROFILE_CS_SUPPORT;
        }
        return scope;
    }

    public static String mapExcelRouteTeamToStageChangeGroup(String excelTeamHint) {
        if (String.isBlank(excelTeamHint)) {
            return null;
        }
        String norm = normalizeToken(excelTeamHint);
        Map<String, String> mapped = new Map<String, String>{
            'cssupport' => 'SP',
            'csom' => 'OM',
            'csf2f' => 'F2F',
            'cardops' => 'CO',
            'payment' => 'PM',
            'cp' => 'CP',
            'cscustomercare' => 'CC',
            'sales' => 'DS',
            'telesales' => 'TS'
        };
        if (mapped.containsKey(norm)) {
            return mapped.get(norm);
        }
        return excelTeamHint.trim();
    }

    private static String buildScopeErrorMessage(String businessProcessCode, String userGroup) {
        String bp = String.isBlank(businessProcessCode) ? FEC_ConstantCommon.STR_EMPTY : businessProcessCode.trim();
        String ug = String.isBlank(userGroup) ? FEC_ConstantCommon.STR_EMPTY : userGroup.trim();
        return String.format(ERR_IMPORT_OUT_OF_SCOPE, new List<String>{ bp, ug });
    }

    private static String normalizeBusinessProcessKey(String businessProcessCode) {
        return String.isBlank(businessProcessCode)
            ? FEC_ConstantCommon.STR_EMPTY
            : businessProcessCode.trim().toUpperCase();
    }

    private static String normalizeToken(String value) {
        if (String.isBlank(value)) {
            return FEC_ConstantCommon.STR_EMPTY;
        }
        return value.trim().toLowerCase().replaceAll('\\s+', FEC_ConstantCommon.STR_EMPTY);
    }
}
