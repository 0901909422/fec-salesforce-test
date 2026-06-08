/**
 * @description Placeholder callback class for Metadata API deployment.
 * Currently unused — FEC_MetadataFieldCreator uses synchronous Tooling API.
 * Kept for future async deployment support.
 * @date 2026-04-21
 */
public with sharing class FEC_MetadataDeployCallback implements Metadata.DeployCallback {

    private String fieldApiName;

    public FEC_MetadataDeployCallback(String fieldApiName) {
        this.fieldApiName = fieldApiName;
    }

    public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
        if (result.status == Metadata.DeployStatus.Succeeded) {
            System.debug('FEC_DEBUG MetadataDeployCallback: SUCCESS - field ' + fieldApiName);
        } else {
            System.debug('FEC_DEBUG MetadataDeployCallback: FAILED - field ' + fieldApiName);
        }
    }
}