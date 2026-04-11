// Find ALL guest user profiles and their sites
List<Profile> guestProfiles = [SELECT Id, Name, UserLicenseId FROM Profile WHERE UserType = 'Guest' OR Name LIKE '%Guest%'];
System.debug('=== Guest Profiles ===');
for (Profile p : guestProfiles) {
    System.debug('Profile: ' + p.Id + ' | ' + p.Name);
}

// Find all sites
List<Site> sites = [SELECT Id, Name, GuestUserId, Status, Subdomain, MasterLabel FROM Site WHERE Status = 'Active'];
System.debug('=== Active Sites ===');
for (Site s : sites) {
    System.debug('Site: ' + s.Name + ' | ' + s.MasterLabel + ' | GuestUser=' + s.GuestUserId + ' | Status=' + s.Status);
}

// Find guest users
List<User> guestUsers = [SELECT Id, Name, ProfileId, Profile.Name FROM User WHERE UserType = 'Guest'];
System.debug('=== Guest Users ===');
for (User u : guestUsers) {
    System.debug('User: ' + u.Id + ' | ' + u.Name + ' | ProfileId=' + u.ProfileId + ' | Profile=' + u.Profile.Name);
}
