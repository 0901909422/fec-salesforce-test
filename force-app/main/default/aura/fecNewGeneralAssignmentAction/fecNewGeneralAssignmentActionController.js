({
    handleCancel: function(component, event, helper) {
        $A.get('e.force:closeQuickAction').fire();
    },
    handleSave: function(component, event, helper) {
        $A.get('e.force:closeQuickAction').fire();
        $A.get('e.force:refreshView').fire();
    }
})
