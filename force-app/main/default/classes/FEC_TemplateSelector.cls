/**
 * Selector Layer: Centralised SOQL for FEC_Template__c.
 * @created  : 2026/03/12
 */
public with sharing class FEC_TemplateSelector {

    /* ─── Standard field list used across queries ─── */
    private static final List<String> BASE_FIELDS = new List<String>{
        'Id',
        'Name',
        'FEC_API_Name__c',
        'FEC_Description__c',
        'FEC_Folder__c',
        'FEC_Folder__r.Name',
        'FEC_Enhanced_Letterhead__c',
        'FEC_Enhanced_Letterhead__r.Name',
        'FEC_Applicable_for_Mailbox__c',
        'FEC_Active__c',
        'FEC_Subject_Line__c',
        'FEC_Body__c',
        'FEC_Date__c',
        'LastModifiedById',
        'LastModifiedBy.Name',
        'LastModifiedDate',
        'CreatedDate'
    };

    /**
     * Get a single template by Id with all fields.
     * @param templateId  The record Id
     * @return FEC_Template__c or null
     */
    public static FEC_Template__c selectById(Id templateId) {
        List<FEC_Template__c> results = Database.query(
            buildBaseQuery() +
            ' WHERE Id = :templateId' +
            ' LIMIT 1'
        );
        return results.isEmpty() ? null : results[0];
    }

    /**
     * Get templates by a set of Ids.
     * @param templateIds  Set of record Ids
     * @return List of FEC_Template__c
     */
    public static List<FEC_Template__c> selectByIds(Set<Id> templateIds) {
        return Database.query(
            buildBaseQuery() +
            ' WHERE Id IN :templateIds' +
            ' ORDER BY Name ASC'
        );
    }

    /**
     * Get all templates – used by the list view.
     * Supports optional filters: folderId, search text, active status.
     * @param folderId      Filter by folder (null = all)
     * @param searchText    LIKE search on name/description (blank = all)
     * @param activeOnly    true = only active templates
     * @return List of FEC_Template__c
     */
    public static List<FEC_Template__c> selectByFilter(
        Id folderId,
        String searchText,
        Boolean activeOnly
    ) {
        String soql = buildBaseQuery();
        List<String> conditions = new List<String>();

        if (folderId != null) {
            conditions.add('FEC_Folder__c = :folderId');
        }

        if (String.isNotBlank(searchText)) {
            // Bind-variable safe LIKE pattern
            searchText = '%' + String.escapeSingleQuotes(searchText.trim()) + '%';
            conditions.add('(Name LIKE :searchText OR FEC_Description__c LIKE :searchText)');
        }

        if (activeOnly == true) {
            conditions.add('FEC_Active__c = TRUE');
        } else if (activeOnly == false) {
            conditions.add('FEC_Active__c = FALSE');
        }
        // activeOnly == null → no filter (return all)

        if (!conditions.isEmpty()) {
            soql += ' WHERE ' + String.join(conditions, ' AND ');
        }

        soql += ' ORDER BY Name ASC';
        soql += ' LIMIT 2000';

        return Database.query(soql);
    }

    /**
     * Get templates belonging to a specific folder.
     * @param folderId  Folder record Id
     * @return List of FEC_Template__c
     */
    public static List<FEC_Template__c> selectByFolderId(Id folderId) {
        return Database.query(
            buildBaseQuery() +
            ' WHERE FEC_Folder__c = :folderId' +
            ' ORDER BY Name ASC'
        );
    }

    /* ─── Private helpers ─── */

    private static String buildBaseQuery() {
        return 'SELECT ' + String.join(BASE_FIELDS, ', ') + ' FROM FEC_Template__c';
    }
}