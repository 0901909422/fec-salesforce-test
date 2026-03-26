/**
 * Controller: @AuraEnabled endpoints for FEC_Folder__c.
 * Thin layer – delegates to FEC_FolderService.
 * Called by LWC components via @wire or imperative Apex.
 * @created  : 2026/03/12
 */
public with sharing class FEC_FolderController {

    /**
     * Get a single folder by Id.
     * Used by fec_folderEditor in edit mode.
     * @param folderId  Record Id
     * @return FEC_Folder__c
     */
    @AuraEnabled
    public static FEC_Folder__c getFolder(Id folderId) {
        try {
            return FEC_FolderService.getFolder(folderId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get all folders – used for dropdown options and tree building.
     * @return List of FEC_Folder__c
     */
    @AuraEnabled
    public static List<FEC_Folder__c> getAllFolders() {
        try {
            return FEC_FolderService.getAllFolders();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get top-level (root) folders.
     * @return List of FEC_Folder__c with no parent
     */
    @AuraEnabled
    public static List<FEC_Folder__c> getTopLevelFolders() {
        try {
            return FEC_FolderService.getTopLevelFolders();
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Get child folders and templates inside a specific folder.
     * Used by fec_folderListView drill-down.
     * @param parentFolderId  Parent folder Id
     * @return Map with 'folders' (List) and 'templates' (List)
     */
    @AuraEnabled
    public static Map<String, Object> getFolderContents(Id parentFolderId) {
        try {
            return FEC_FolderService.getFolderContents(parentFolderId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Save (insert or update) a folder.
     * @param folderJson  JSON-serialised FEC_Folder__c record
     * @return Id of the saved record
     */
    @AuraEnabled
    public static Id saveFolder(String folderJson) {
        try {
            FEC_Folder__c folder = (FEC_Folder__c) JSON.deserialize(
                folderJson, FEC_Folder__c.class
            );
            return FEC_FolderService.saveFolder(folder);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Delete a folder. Validates no children exist before deleting.
     * @param folderId  Record Id
     */
    @AuraEnabled
    public static void deleteFolder(Id folderId) {
        try {
            FEC_FolderService.deleteFolder(folderId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Search folders by keyword.
     * @param searchText  Search keyword
     * @return List of FEC_Folder__c matching the search
     */
    @AuraEnabled
    public static List<FEC_Folder__c> searchFolders(String searchText) {
        try {
            return FEC_FolderService.searchFolders(searchText);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}