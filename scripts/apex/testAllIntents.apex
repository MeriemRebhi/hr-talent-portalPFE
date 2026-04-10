// Test all chat intents
CandidateChatController.ChatResponse r1 = CandidateChatController.chat('bonjour', '');
System.debug('BONJOUR: ' + r1.type + ' | ' + r1.message.substring(0, Math.min(50, r1.message.length())));

CandidateChatController.ChatResponse r2 = CandidateChatController.chat('Offres disponibles', '');
System.debug('OFFRES: ' + r2.type + ' | ' + r2.message.substring(0, Math.min(80, r2.message.length())));

CandidateChatController.ChatResponse r3 = CandidateChatController.chat('statut de mes candidatures', 'eyaboudidah00@gmail.com');
System.debug('STATUT: ' + r3.type + ' | ' + r3.message.substring(0, Math.min(80, r3.message.length())));
