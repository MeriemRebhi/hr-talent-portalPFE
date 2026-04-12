// Change Ahmed and Sami to System Administrator profile
Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
System.debug('Admin Profile: ' + adminProfile.Id);

User ahmed = [SELECT Id, ProfileId, Profile.Name FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];
User sami  = [SELECT Id, ProfileId, Profile.Name FROM User WHERE Username = 'sami.trabelsi.pfe@talan-tunisie.dev' LIMIT 1];

System.debug('Ahmed avant: ' + ahmed.Profile.Name);
System.debug('Sami avant: ' + sami.Profile.Name);

ahmed.ProfileId = adminProfile.Id;
sami.ProfileId  = adminProfile.Id;
update new List<User>{ ahmed, sami };

System.debug('✅ Ahmed → System Administrator');
System.debug('✅ Sami  → System Administrator');
