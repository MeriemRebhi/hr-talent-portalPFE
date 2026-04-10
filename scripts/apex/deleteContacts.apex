// 1. Supprimer les Cases (liés aux contacts démo Salesforce)
List<Case> cases = [SELECT Id FROM Case];
System.debug('Cases à supprimer: ' + cases.size());
if(!cases.isEmpty()) delete cases;

// 2. Supprimer tous les Contacts
List<Contact> c = [SELECT Id FROM Contact];
System.debug('Contacts avant: ' + c.size());
if(!c.isEmpty()) delete c;
System.debug('Contacts après: ' + [SELECT COUNT() FROM Contact]);
