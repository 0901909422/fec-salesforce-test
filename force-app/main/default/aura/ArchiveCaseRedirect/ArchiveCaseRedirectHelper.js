({
    redirect : function(component, recordId) {

        let action = component.get("c.getOrCreateCase");
        action.setParams({
            sfIdForExternalRec: recordId
        });

        action.setCallback(this, function(response) {
            if (response.getState() === "SUCCESS") {
                let caseId = response.getReturnValue();
                console.log('caseId ' + caseId);

                if (caseId != null) {
                    let navEvt = $A.get("e.force:navigateToSObject");
                    navEvt.setParams({
                        recordId: caseId,
                        slideDevName: "detail"
                    });
                    navEvt.fire();
                }
            }
        });

        $A.enqueueAction(action);
    }
})