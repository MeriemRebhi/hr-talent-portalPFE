// Test garde anti-double-scoring
// Ce Lead est déjà converti (Status = Condidat -Converti)
ApplicationController.triggerScoring('00Qfj00000EAkJGEA1');
System.debug('✅ Guard test terminé - aucun Queueable ne devrait être ajouté');
