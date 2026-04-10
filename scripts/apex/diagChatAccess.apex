// Find all Experience Cloud users and their profiles
List<User> users = [
    SELECT Id, Name, Email, Profile.Name, Profile.UserType, ProfileId
    FROM User
    WHERE UserType != 'Standard' AND IsActive = true
    ORDER BY Profile.Name
    LIMIT 20
];
for (User u : users) {
    System.debug('User: ' + u.Name + ' | Email: ' + u.Email + ' | Profile: ' + u.Profile.Name + ' | UserType: ' + u.Profile.UserType + ' | ProfileId: ' + u.ProfileId);
}

// Also show which classes are accessible to each profile
List<String> classNames = new List<String>{'CandidateChatController', 'AgentGetCandidatureStatus', 'AgentGetAnalyseIA', 'AgentGetOffresDisponibles'};
List<ApexClass> classes = [SELECT Id, Name FROM ApexClass WHERE Name IN :classNames];
System.debug('--- Classes in org: ' + classes.size());
for (ApexClass c : classes) System.debug('Class: ' + c.Name + ' | Id: ' + c.Id);
