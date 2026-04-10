List<User> u = [
    SELECT Id, Username, Email, IsActive, UserType, Profile.Name
    FROM User
    WHERE Email = 'm.rebhi24292@pi.tn'
    LIMIT 5
];
for(User uu : u) {
    System.debug('>>> USERNAME: ' + uu.Username);
    System.debug('>>> USERTYPE: ' + uu.UserType);
    System.debug('>>> ISACTIVE: ' + uu.IsActive);
    System.debug('>>> PROFILE: ' + uu.Profile.Name);
}
if (u.isEmpty()) System.debug('>>> AUCUN USER TROUVÉ pour cet email');
