public class FEC_GeneralAssignmentTriggerHandler {
    
    public static void handleAfterInsert(List<FEC_General_Assignment_Config__c> newRecords) {
        processInheritance(newRecords, null);
    }
    
    public static void handleAfterUpdate(List<FEC_General_Assignment_Config__c> newRecords, Map<Id, FEC_General_Assignment_Config__c> oldMap) {
        List<FEC_General_Assignment_Config__c> recordsToProcess = new List<FEC_General_Assignment_Config__c>();
        
        for (FEC_General_Assignment_Config__c ga : newRecords) {
            FEC_General_Assignment_Config__c oldGA = oldMap.get(ga.Id);
            // Only process if Nature of Case changed
            if (ga.FEC_Nature_of_Cases__c != oldGA.FEC_Nature_of_Cases__c) {
                recordsToProcess.add(ga);
            }
        }
        
        if (!recordsToProcess.isEmpty()) {
            processInheritance(recordsToProcess, null);
        }
    }
    
    private static void processInheritance(List<FEC_General_Assignment_Config__c> gaRecords, Map<Id, FEC_General_Assignment_Config__c> oldMap) {
        Set<Id> nocIds = new Set<Id>();
        
        for (FEC_General_Assignment_Config__c ga : gaRecords) {
            if (ga.FEC_Nature_of_Cases__c != null) {
                nocIds.add(ga.FEC_Nature_of_Cases__c);
            }
        }
        
        if (nocIds.isEmpty()) {
            return;
        }
        
        // Get all child Nature of Cases
        Map<Id, List<Id>> parentToChildrenMap = getChildNatureOfCases(nocIds);
        
        if (parentToChildrenMap.isEmpty()) {
            return;
        }
        
        // Get existing General Assignments for children
        Set<Id> allChildNocIds = new Set<Id>();
        for (List<Id> children : parentToChildrenMap.values()) {
            allChildNocIds.addAll(children);
        }
        
        Map<Id, Set<String>> existingGAByNoc = getExistingGeneralAssignments(allChildNocIds);
        
        // Create new General Assignments for children
        List<FEC_General_Assignment_Config__c> newGAs = new List<FEC_General_Assignment_Config__c>();
        
        for (FEC_General_Assignment_Config__c parentGA : gaRecords) {
            if (parentGA.FEC_Nature_of_Cases__c == null) {
                continue;
            }
            
            List<Id> childNocIds = parentToChildrenMap.get(parentGA.FEC_Nature_of_Cases__c);
            if (childNocIds == null || childNocIds.isEmpty()) {
                continue;
            }
            
            String gaKey = generateGAKey(parentGA);
            
            for (Id childNocId : childNocIds) {
                Set<String> existingKeys = existingGAByNoc.get(childNocId);
                
                // Only create if child doesn't have this config yet
                if (existingKeys == null || !existingKeys.contains(gaKey)) {
                    FEC_General_Assignment_Config__c childGA = new FEC_General_Assignment_Config__c();
                    childGA.FEC_Nature_of_Cases__c = childNocId;
                    childGA.FEC_Customer_Type__c = parentGA.FEC_Customer_Type__c;
                    childGA.FEC_Channel__c = parentGA.FEC_Channel__c;
                    childGA.FEC_Case_Stage__c = parentGA.FEC_Case_Stage__c;
                    childGA.FEC_General_Assignment_Name__c = parentGA.FEC_General_Assignment_Name__c;
                    childGA.FEC_General_Assignment_Code__c = parentGA.FEC_General_Assignment_Code__c;
                    childGA.FEC_Active__c = parentGA.FEC_Active__c;
                    
                    newGAs.add(childGA);
                }
            }
        }
        
        if (!newGAs.isEmpty()) {
            insert newGAs;
        }
    }
    
    private static Map<Id, List<Id>> getChildNatureOfCases(Set<Id> parentNocIds) {
        Map<Id, List<Id>> parentToChildrenMap = new Map<Id, List<Id>>();
        
        // Query all Nature of Cases with hierarchy fields
        Map<Id, FEC_Nature_of_Case__c> allNocs = new Map<Id, FEC_Nature_of_Case__c>([
            SELECT Id, FEC_Product_Type__c, FEC_Category__c, FEC_Sub_Category__c, FEC_Sub_Code__c
            FROM FEC_Nature_of_Case__c
        ]);
        
        Map<Id, FEC_Nature_of_Case__c> parentNocs = new Map<Id, FEC_Nature_of_Case__c>();
        for (Id nocId : parentNocIds) {
            if (allNocs.containsKey(nocId)) {
                parentNocs.put(nocId, allNocs.get(nocId));
            }
        }
        
        // For each parent, find all children
        for (Id parentId : parentNocs.keySet()) {
            FEC_Nature_of_Case__c parent = parentNocs.get(parentId);
            List<Id> children = new List<Id>();
            
            for (FEC_Nature_of_Case__c noc : allNocs.values()) {
                if (noc.Id == parentId) {
                    continue;
                }
                
                if (isChildOf(noc, parent)) {
                    children.add(noc.Id);
                }
            }
            
            if (!children.isEmpty()) {
                parentToChildrenMap.put(parentId, children);
            }
        }
        
        return parentToChildrenMap;
    }
    
    private static Boolean isChildOf(FEC_Nature_of_Case__c child, FEC_Nature_of_Case__c parent) {
        // Check hierarchy: child must have all parent's fields + more specific
        
        // If parent has Sub Code, child must match exactly (no children possible)
        if (parent.FEC_Sub_Code__c != null) {
            return false;
        }
        
        // If parent has Sub Category, child must match and have Sub Code
        if (parent.FEC_Sub_Category__c != null) {
            return child.FEC_Product_Type__c == parent.FEC_Product_Type__c
                && child.FEC_Category__c == parent.FEC_Category__c
                && child.FEC_Sub_Category__c == parent.FEC_Sub_Category__c
                && child.FEC_Sub_Code__c != null;
        }
        
        // If parent has Category, child must match and have Sub Category or Sub Code
        if (parent.FEC_Category__c != null) {
            return child.FEC_Product_Type__c == parent.FEC_Product_Type__c
                && child.FEC_Category__c == parent.FEC_Category__c
                && (child.FEC_Sub_Category__c != null || child.FEC_Sub_Code__c != null);
        }
        
        // If parent has only Product Type, child must match and have Category, Sub Category, or Sub Code
        if (parent.FEC_Product_Type__c != null) {
            return child.FEC_Product_Type__c == parent.FEC_Product_Type__c
                && (child.FEC_Category__c != null || child.FEC_Sub_Category__c != null || child.FEC_Sub_Code__c != null);
        }
        
        return false;
    }
    
    private static Map<Id, Set<String>> getExistingGeneralAssignments(Set<Id> nocIds) {
        Map<Id, Set<String>> existingGAByNoc = new Map<Id, Set<String>>();
        
        List<FEC_General_Assignment_Config__c> existingGAs = [
            SELECT Id, FEC_Nature_of_Cases__c, FEC_Customer_Type__c, FEC_Channel__c, 
                   FEC_Case_Stage__c, FEC_General_Assignment_Name__c
            FROM FEC_General_Assignment_Config__c
            WHERE FEC_Nature_of_Cases__c IN :nocIds
        ];
        
        for (FEC_General_Assignment_Config__c ga : existingGAs) {
            String key = generateGAKey(ga);
            
            if (!existingGAByNoc.containsKey(ga.FEC_Nature_of_Cases__c)) {
                existingGAByNoc.put(ga.FEC_Nature_of_Cases__c, new Set<String>());
            }
            
            existingGAByNoc.get(ga.FEC_Nature_of_Cases__c).add(key);
        }
        
        return existingGAByNoc;
    }
    
    private static String generateGAKey(FEC_General_Assignment_Config__c ga) {
        // Generate unique key based on config fields
        return String.valueOf(ga.FEC_Customer_Type__c) + '|' 
             + String.valueOf(ga.FEC_Channel__c) + '|'
             + String.valueOf(ga.FEC_Case_Stage__c) + '|'
             + String.valueOf(ga.FEC_General_Assignment_Name__c);
    }
}

