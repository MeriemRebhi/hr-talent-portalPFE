// Check if CandidateChatController is accessible to Customer Community Login User
Id communityProfileId = '00efj000008FSMAAA4'; // Customer Community Login User
Id chatClassId = '01pfj00000AOnEjAAL'; // CandidateChatController

// Get the profile's owned permission set
List<PermissionSet> psSets = [
    SELECT Id, Name FROM PermissionSet
    WHERE ProfileId = :communityProfileId AND IsOwnedByProfile = true
];
System.debug('Profile PermSetCount: ' + psSets.size());
if (!psSets.isEmpty()) System.debug('Profile PermSet Id: ' + psSets[0].Id);

// Check access
List<SetupEntityAccess> access = [
    SELECT Id, SetupEntityId, ParentId FROM SetupEntityAccess
    WHERE SetupEntityId = :chatClassId AND ParentId IN :psSets
];
System.debug('Access grants to CandidateChatController: ' + access.size());

if (access.isEmpty() && !psSets.isEmpty()) {
    // Grant it
    SetupEntityAccess sea = new SetupEntityAccess();
    sea.ParentId = psSets[0].Id;
    sea.SetupEntityId = chatClassId;
    insert sea;
    System.debug('GRANTED CandidateChatController to Customer Community Login User');
} else {
    System.debug('Already granted or no profile perm set found');
}
