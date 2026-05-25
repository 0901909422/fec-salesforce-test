/**
 * Selector Layer: Centralised SOQL for FEC_Folder__c.
 * Supports hierarchy traversal (parent/child) and search.
 * @created  : 2026/03/12
 */
public with sharing class FEC_FolderSelector {

    /* ─── Standard field list ─── */
    private static final List<String> BASE_FIELDS = new List<String>{
        'Id',
        'Name',
        'FEC_Folder_Unique_Name__c',
        'FEC_Parent_Folder__c',
        'FEC_Parent_Folder__r.Name',
        'LastModifiedBy.Name',
        'LastModifiedDate',
        'CreatedDate'
    };

    /**
     * Get a single folder by Id.
     * @param folderId  Record Id
     * @return FEC_Folder__c or null
     */
    public static FEC_Folder__c selectById(Id folderId) {
        List<FEC_Folder__c> results = Database.query(
            buildBaseQuery() +
            ' WHERE Id = :folderId' +
            ' LIMIT 1'
        );
        return results.isEmpty() ? null : results[0];
    }

    /**
     * Get all folders – used to build the tree / dropdown options.
     * @return List of FEC_Folder__c ordered by label
     */
    public static List<FEC_Folder__c> selectAll() {
        return Database.query(
            buildBaseQuery() +
            ' ORDER BY Name ASC' +
            ' LIMIT 2000'
        );
    }

    /**
     * Get top-level folders (no parent).
     * @return List of FEC_Folder__c
     */
    public static List<FEC_Folder__c> selectTopLevel() {
        return Database.query(
            buildBaseQuery() +
            ' WHERE FEC_Parent_Folder__c = NULL' +
            ' ORDER BY Name ASC'
        );
    }

    /**
     * Get child folders of a parent.
     * @param parentFolderId  Parent folder record Id
     * @return List of FEC_Folder__c
     */
    public static List<FEC_Folder__c> selectByParentId(Id parentFolderId) {
        return Database.query(
            buildBaseQuery() +
            ' WHERE FEC_Parent_Folder__c = :parentFolderId' +
            ' ORDER BY Name ASC'
        );
    }

    /**
     * Search folders by label (LIKE pattern).
     * @param searchText  Search keyword
     * @return List of FEC_Folder__c
     */
    public static List<FEC_Folder__c> selectBySearch(String searchText) {
        if (String.isBlank(searchText)) {
            return selectAll();
        }
        searchText = '%' + String.escapeSingleQuotes(searchText.trim()) + '%';
        return Database.query(
            buildBaseQuery() +
            ' WHERE Name LIKE :searchText' +
            ' ORDER BY Name ASC' +
            ' LIMIT 2000'
        );
    }

    /* ─── Private helpers ─── */

    private static String buildBaseQuery() {
        return 'SELECT ' + String.join(BASE_FIELDS, ', ') + ' FROM FEC_Folder__c';
    }
}