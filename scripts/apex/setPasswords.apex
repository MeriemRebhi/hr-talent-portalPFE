// Set passwords for Ahmed and Sami
User ahmed = [SELECT Id, Username FROM User WHERE Username = 'ahmed.bensalah.pfe@talan-tunisie.dev' LIMIT 1];
User sami  = [SELECT Id, Username FROM User WHERE Username = 'sami.trabelsi.pfe@talan-tunisie.dev' LIMIT 1];

System.setPassword(ahmed.Id, 'TalanPFE@2026x');
System.debug('✅ Ahmed password set: TalanPFE@2026x');
System.debug('   Username: ' + ahmed.Username);

System.setPassword(sami.Id, 'TalanPFE@2026x');
System.debug('✅ Sami password set: TalanPFE@2026x');
System.debug('   Username: ' + sami.Username);

System.debug('');
System.debug('═══════════════════════════════════════');
System.debug('  CONNEXION AHMED (Recruteur Java/Data):');
System.debug('  URL: https://orgfarm-3ed211f8bb-dev-ed.develop.my.salesforce.com');
System.debug('  Username: ahmed.bensalah.pfe@talan-tunisie.dev');
System.debug('  Password: Talan2026!pfe');
System.debug('');
System.debug('  CONNEXION SAMI (Manager):');
System.debug('  URL: https://orgfarm-3ed211f8bb-dev-ed.develop.my.salesforce.com');
System.debug('  Username: sami.trabelsi.pfe@talan-tunisie.dev');
System.debug('  Password: Talan2026!pfe');
System.debug('═══════════════════════════════════════');
