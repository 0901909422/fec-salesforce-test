({
    doInit : function(component, event, helper) {
        
    },

    handleClose : function(component, event, helper) {
         var recordId =  component.get("v.recordId");
         if (recordId) {
            component.find('overlayLib').notifyClose();
            return;
         }
         var workspaceAPI = component.find("workspace");

        workspaceAPI.isConsoleNavigation().then(function(isConsole) {
            if (isConsole) {
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                        workspaceAPI.closeTab({tabId: response.tabId});
                    });
                // CASE 1: Console App - Find the current tab and close it
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    var focusedTabId = response.tabId;
                    workspaceAPI.closeTab({tabId: focusedTabId});
                })
                .catch(function(error) {
                    console.log("Error closing tab: ", error);
                });
            } else {
                // CASE 2: Standard App - Navigate back to Object Home (Previous screen)
                component.find('overlayLib').notifyClose();
                helper.navigateToListView();
            }
        });
        
    },

    handleSaveSuccess : function(component, event, helper) {
        console.log('handleSuccess');
        // 1. Get the recordId passed from LWC detail object
        var recordId = event.getParam('recordId');
        var navService = component.find("navService");
        
        // 2. Define the page reference for the new record detail
        var pageReference = {
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'EnhancedLetterhead', // Ensure this matches your object
                actionName: 'view'
            }
        };

        // 3. Navigate to the detail page
        navService.navigate(pageReference);

        // 4. (Optional) Close the current "New" tab to clean up the workspace
        var workspaceAPI = component.find("workspace");
        workspaceAPI.getFocusedTabInfo().then(function(response) {
            var focusedTabId = response.tabId;
            workspaceAPI.closeTab({tabId: focusedTabId});
        })
        .catch(function(error) {
            console.error("Workspace Error: ", error);
        });
    }, 
})