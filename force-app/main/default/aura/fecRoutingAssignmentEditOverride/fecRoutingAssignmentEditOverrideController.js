({
    init: function(component, event, helper) {
        // Nothing needed on init
    },
    handleClose: function(component, event, helper) {
        // Navigate back to record detail page
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            "recordId": component.get("v.recordId"),
            "slideDevName": "detail"
        });
        navEvt.fire();
    }
})
