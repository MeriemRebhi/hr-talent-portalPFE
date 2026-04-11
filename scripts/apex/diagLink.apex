// Test getInterviewInfo for oppId 006fj00000BRMfdAAH
Id testOppId = '006fj00000BRMfdAAH';
try {
    Map<String, Object> info = TechnicalInterviewController.getInterviewInfo(testOppId);
    System.debug('=== getInterviewInfo ===');
    for (String k : info.keySet()) {
        System.debug('  ' + k + ': ' + info.get(k));
    }
} catch (Exception e) {
    System.debug('ERROR: ' + e.getTypeName() + ' - ' + e.getMessage());
    System.debug('STACK: ' + e.getStackTraceString());
}
