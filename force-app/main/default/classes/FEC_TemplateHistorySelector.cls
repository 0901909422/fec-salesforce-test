/**
 * Selector Layer: Centralised SOQL for FEC_Template__History.
 * Queries field-level change history for a specific template.
 * @created  : 2026/03/19
 */
public with sharing class FEC_TemplateHistorySelector {

    /* ─── Standard field list ─── */
    private static final List<String> BASE_FIELDS = new List<String>{
        'Id',
        'ParentId',
        'Field',
        'OldValue',
        'NewValue',
        'CreatedById',
        'CreatedBy.Name',
        'CreatedDate'
    };

    /**
     * Get template history records for a specific template.
     * Ordered by date descending (most recent first).
     * @param templateId  The parent template Id
     * @return List of FEC_Template__History
     */
    public static List<FEC_Template__History> selectByTemplateId(Id templateId) {
        return Database.query(
            buildBaseQuery() +
            ' WHERE ParentId = :templateId' +
            ' ORDER BY CreatedDate DESC' +
            ' LIMIT 200'
        );
    }

    /**
     * Get a single template history record by Id.
     * @param recordId  The record Id
     * @return FEC_Template__History or null
     */
    public static FEC_Template__History selectById(Id recordId) {
        List<FEC_Template__History> results = Database.query(
            buildBaseQuery() +
            ' WHERE Id = :recordId' +
            ' LIMIT 1'
        );
        return results.isEmpty() ? null : results[0];
    }

    /* ─── Private helpers ─── */

    private static String buildBaseQuery() {
        return 'SELECT ' + String.join(BASE_FIELDS, ', ') + ' FROM FEC_Template__History';
    }
}