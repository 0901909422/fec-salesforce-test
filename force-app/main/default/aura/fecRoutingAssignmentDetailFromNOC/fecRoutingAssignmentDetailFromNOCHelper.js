({
    loadRecordName: function(component) {
        var recordId = component.get("v.recordId");
        if (recordId) {
            var action = component.get("c.getRoutingAssignmentName");
            action.setParams({ recordId: recordId });
            action.setCallback(this, function(response) {
                if (response.getState() === "SUCCESS") {
                    var name = response.getReturnValue();
                    component.set("v.recordName", name);
                    var workspace = component.find("workspace");
                    if (workspace) {
                        workspace.getEnclosingTabId().then(function(tabId) {
                            workspace.setTabLabel({ tabId: tabId, label: name });
                            workspace.setTabIcon({ tabId: tabId, icon: "custom:custom49", iconAlt: "Routing Assignment" });
                        }).catch(function() {});
                    }
                }
            });
            $A.enqueueAction(action);
        }
    }
})
