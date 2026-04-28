/**
 * Schedulable job to sync location data from external source.
 *
 * Schedule via Anonymous Apex:
 *   // Daily at 2:00 AM
 *   System.schedule('Location Sync Daily', '0 0 2 * * ?', new FEC_LocationSyncScheduler());
 *
 *   // Every 6 hours
 *   System.schedule('Location Sync 6h', '0 0 0,6,12,18 * * ?', new FEC_LocationSyncScheduler());
 */
public class FEC_LocationSyncScheduler implements Schedulable {

    public void execute(SchedulableContext sc) {
        FEC_IntegrationLocationService.syncLocation();
    }
}