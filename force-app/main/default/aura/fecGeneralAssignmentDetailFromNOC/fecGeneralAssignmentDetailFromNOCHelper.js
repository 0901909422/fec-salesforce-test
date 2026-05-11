({
    loadRecordName: function(component) {
        var recordId = component.get("v.recordId");
        if (recordId) {
            var action = component.get("c.getRecordName");
            action.setParams({ recordId: recordId });
            action.setCallback(this, function(response) {
                if (response.getState() === "SUCCESS") {
                    var recordName = response.getReturnValue();
                    component.set("v.recordName", recordName);
                    // Update tab label and icon in console app
                    var workspace = component.find("workspace");
                    if (workspace) {
                        workspace.getEnclosingTabId().then(function(tabId) {
                            workspace.setTabLabel({ tabId: tabId, label: recordName });
                            workspace.setTabIcon({ tabId: tabId, icon: "custom:custom70", iconAlt: "General Assignment" });
                        }).catch(function() {});
                    }
                }
            });
            $A.enqueueAction(action);
        }
    },

    publishEditMode: function(component, recordId) {
        var message = { recordId: recordId };
        component.find("editModeChannel").publish(message);
    }
})
