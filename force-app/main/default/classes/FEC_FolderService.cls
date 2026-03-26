/**
 * Service Layer: Business logic for FEC_Folder__c.
 * Orchestrates Selector queries and DML for folder CRUD.
 * Called by controllers; never directly by LWC.
 * @created  : 2026/03/12
 */
public with sharing class FEC_FolderService {

    /**
     * Get a single folder by Id.
     * @param folderId  Record Id
     * @return FEC_Folder__c or null
     */
    public static FEC_Folder__c getFolder(Id folderId) {
        return FEC_FolderSelector.selectById(folderId);
    }

    /**
     * Get all folders for dropdown / tree building.
     * @return List of all FEC_Folder__c records
     */
    public static List<FEC_Folder__c> getAllFolders() {
        return FEC_FolderSelector.selectAll();
    }

    /**
     * Get top-level (root) folders.
     * @return List of FEC_Folder__c without a parent
     */
    public static List<FEC_Folder__c> getTopLevelFolders() {
        return FEC_FolderSelector.selectTopLevel();
    }

    /**
     * Get child folders + child templates for a given parent folder.
     * Used by the folder drill-down view.
     * @param parentFolderId  Parent folder Id
     * @return Map with 'folders' and 'templates' keys
     */
    public static Map<String, Object> getFolderContents(Id parentFolderId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('folders', FEC_FolderSelector.selectByParentId(parentFolderId));
        result.put('templates', FEC_TemplateSelector.selectByFolderId(parentFolderId));
        return result;
    }

    /**
     * Create or update a folder.
     * @param folder  The folder record to upsert
     * @return Id of the saved record
     */
    public static Id saveFolder(FEC_Folder__c folder) {
        if (folder.Id == null) {
            if (!Schema.sObjectType.FEC_Folder__c.isCreateable()) {
                throw new FEC_APIServiceException('Insufficient privileges to create folders.');
            }
        } else {
            if (!Schema.sObjectType.FEC_Folder__c.isUpdateable()) {
                throw new FEC_APIServiceException('Insufficient privileges to update folders.');
            }
        }
        upsert folder;
        return folder.Id;
    }

    /**
     * Delete a folder by Id.
     * Validates that the folder has no child folders or templates before deletion.
     * @param folderId  Record Id
     */
    public static void deleteFolder(Id folderId) {
        if (!Schema.sObjectType.FEC_Folder__c.isDeletable()) {
            throw new FEC_APIServiceException('Insufficient privileges to delete folders.');
        }

        // Guard: prevent deleting a folder that still has children
        List<FEC_Folder__c> childFolders = FEC_FolderSelector.selectByParentId(folderId);
        if (!childFolders.isEmpty()) {
            throw new FEC_APIServiceException(
                'Cannot delete folder: it still contains ' + childFolders.size() + ' sub-folder(s). '
                + 'Move or delete them first.'
            );
        }

        List<FEC_Template__c> childTemplates = FEC_TemplateSelector.selectByFolderId(folderId);
        if (!childTemplates.isEmpty()) {
            throw new FEC_APIServiceException(
                'Cannot delete folder: it still contains ' + childTemplates.size() + ' template(s). '
                + 'Move or delete them first.'
            );
        }

        delete new FEC_Folder__c(Id = folderId);
    }

    /**
     * Search folders by keyword.
     * @param searchText  Keyword to search in label
     * @return List of matching FEC_Folder__c
     */
    public static List<FEC_Folder__c> searchFolders(String searchText) {
        return FEC_FolderSelector.selectBySearch(searchText);
    }
}