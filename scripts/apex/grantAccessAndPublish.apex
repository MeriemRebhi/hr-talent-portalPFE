// Grant Guest User profile access to Technical_Interview__c
// Find the guest user profile
Profile guestProfile = [SELECT Id, Name FROM Profile WHERE Id = '00efj000008OTBdAAO' LIMIT 1];
System.debug('Guest Profile: ' + guestProfile.Name);

// Grant Object permissions via PermissionSet assigned to Guest User
// The without sharing on TechnicalInterviewController already handles CRUD bypass
// But we also need to ensure the permission set is assigned

// Check if our permission set exists
List<PermissionSet> ps = [SELECT Id, Name FROM PermissionSet WHERE Name = 'Security_Objects_Full_Access' LIMIT 1];
if (!ps.isEmpty()) {
    System.debug('Permission Set found: ' + ps[0].Id);
    
    // Check if it's assigned to the guest user
    Id guestUserId = '005fj00000DMi8fAAD';
    List<PermissionSetAssignment> existing = [
        SELECT Id FROM PermissionSetAssignment 
        WHERE PermissionSetId = :ps[0].Id AND AssigneeId = :guestUserId
    ];
    if (existing.isEmpty()) {
        System.debug('Assigning permission set to guest user...');
        try {
            insert new PermissionSetAssignment(
                PermissionSetId = ps[0].Id,
                AssigneeId = guestUserId
            );
            System.debug('Permission set assigned successfully!');
        } catch (Exception e) {
            System.debug('Assignment error: ' + e.getMessage());
        }
    } else {
        System.debug('Permission set already assigned to guest user');
    }
}

// Republish the site
try {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/connect/communities/0DBfj000001sohhGAA/publish');
    req.setMethod('POST');
    req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
    req.setHeader('Content-Type', 'application/json');
    req.setBody('{}');
    HttpResponse res = new Http().send(req);
    System.debug('Publish site: ' + res.getStatusCode() + ' ' + res.getBody());
} catch (Exception e) {
    System.debug('Publish error: ' + e.getMessage());
}
