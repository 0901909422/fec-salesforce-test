({
    handleClose : function(component, event, helper) {
        console.log('handleClose');
        var workspaceAPI = component.find("workspace");

        workspaceAPI.isConsoleNavigation().then(function(isConsole) {
            if (isConsole) {
                window.history.back();
                // 4. (Optional) Close the current "New" tab to clean up the workspace
                var workspaceAPI = component.find("workspace");
                workspaceAPI.getFocusedTabInfo().then(function(response) {
                    var focusedTabId = response.tabId;
                    workspaceAPI.closeTab({tabId: focusedTabId});
                })
                .catch(function(error) {
                    console.error("Workspace Error: ", error);
                });
                
            } else {
                // CASE 2: Standard App - Navigate back to Object Home (Previous screen)
                component.find('overlayLib').notifyClose();
                helper.navigateToListView();
            }
        });
        
    },
    handleRecordUpdated: function(component, event, helper) {
        var eventParams = event.getParams();
        if(eventParams.changeType === "LOADED") {
            // Set the result back to an attribute
            component.set("v.headerEditLabel", "Edit " + component.get("v.letterheadFields").Name);
        } else if(eventParams.changeType === "ERROR") {
            console.error('Error: ' + component.get("v.recordError"));
        }
    },
})