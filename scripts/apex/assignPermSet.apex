// Assign the Security_Objects_Full_Access permission set to the current admin user
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Security_Objects_Full_Access' LIMIT 1];
Id userId = UserInfo.getUserId();

List<PermissionSetAssignment> existing = [
    SELECT Id FROM PermissionSetAssignment 
    WHERE PermissionSetId = :ps.Id AND AssigneeId = :userId
];

if (existing.isEmpty()) {
    PermissionSetAssignment psa = new PermissionSetAssignment();
    psa.PermissionSetId = ps.Id;
    psa.AssigneeId = userId;
    insert psa;
    System.debug('✅ PermissionSet assigned to admin user: ' + UserInfo.getUserName());
} else {
    System.debug('Already assigned');
}
