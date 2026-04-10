// Find the specific site/network for home2 and its guest user
List<Site> sites = [SELECT Id, Name, GuestUserId, MasterLabel, Status FROM Site WHERE Status = 'Active'];
System.debug('Active sites: ' + sites.size());
for (Site s : sites) {
    System.debug('Site: ' + s.Name + ' | Label: ' + s.MasterLabel + ' | GuestUser: ' + s.GuestUserId + ' | Status: ' + s.Status);
    
    if (s.GuestUserId != null) {
        User gu = [SELECT Id, Name, ProfileId, Profile.Name FROM User WHERE Id = :s.GuestUserId];
        System.debug('  Guest User: ' + gu.Name + ' | Profile: ' + gu.Profile.Name + ' | ProfileId: ' + gu.ProfileId);
        
        // Find the profile-owned permission set for this specific profile
        List<PermissionSet> ps = [SELECT Id, Name FROM PermissionSet WHERE ProfileId = :gu.ProfileId AND IsOwnedByProfile = true LIMIT 1];
        if (!ps.isEmpty()) {
            System.debug('  Profile PS: ' + ps[0].Id + ' | ' + ps[0].Name);
            
            // Check if GamingTestController access exists
            ApexClass ctrl = [SELECT Id FROM ApexClass WHERE Name = 'GamingTestController' LIMIT 1];
            List<SetupEntityAccess> existing = [SELECT Id FROM SetupEntityAccess WHERE ParentId = :ps[0].Id AND SetupEntityId = :ctrl.Id];
            System.debug('  Has GamingTestController access: ' + !existing.isEmpty());
            
            if (existing.isEmpty()) {
                try {
                    insert new SetupEntityAccess(ParentId = ps[0].Id, SetupEntityId = ctrl.Id);
                    System.debug('  >>> GRANTED GamingTestController access');
                } catch (Exception e) {
                    System.debug('  >>> GRANT FAILED: ' + e.getMessage());
                }
            }
        }
    }
}

// Also check Networks (communities)
List<Network> networks = [SELECT Id, Name, Status FROM Network WHERE Status = 'Live'];
System.debug('Live networks: ' + networks.size());
for (Network n : networks) {
    System.debug('Network: ' + n.Name + ' | Id: ' + n.Id);
}
