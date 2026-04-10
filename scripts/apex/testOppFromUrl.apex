// Test getTestInfo with the exact oppId from the URL
try {
    Map<String, Object> info = GamingTestController.getTestInfo('006fj00000B8sZaAAJ');
    System.debug('SUCCESS: ' + info);
} catch (Exception e) {
    System.debug('FAILED: ' + e.getMessage());
    System.debug('Type: ' + e.getTypeName());
}
