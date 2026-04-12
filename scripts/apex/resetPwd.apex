User sami = [SELECT Id, Username, IsActive FROM User WHERE Username = 'sami.trabelsi.pfe@talan-tunisie.dev' LIMIT 1];
System.debug('Sami: ' + sami.Username + ' | Active: ' + sami.IsActive);
System.setPassword(sami.Id, 'Talan@Demo2026');
System.debug('✅ Nouveau mot de passe: Talan@Demo2026');

User ahmed = [SELECT Id, Username, IsActive FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];
System.debug('Ahmed: ' + ahmed.Username + ' | Active: ' + ahmed.IsActive);
System.setPassword(ahmed.Id, 'Talan@Demo2026');
System.debug('✅ Nouveau mot de passe: Talan@Demo2026');
