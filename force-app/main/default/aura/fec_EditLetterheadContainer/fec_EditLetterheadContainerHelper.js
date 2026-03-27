({
    navigateToListView : function() {
        var navEvent = $A.get("e.force:navigateToObjectHome");
        navEvent.setParams({
            "scope": "FEC_Enhanced_Letterhead__c"
        });
        navEvent.fire();
    }
})