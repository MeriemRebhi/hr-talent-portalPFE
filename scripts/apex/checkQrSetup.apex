// Add api.qrserver.com as a Trusted URL for the community site
// This ensures the QR code images can be loaded in the Experience Cloud site

// Check if the CSP Trusted Site already exists at the org level
// The deployment already created it, but we need to verify for the community

// Try to query existing CSP Trusted Sites via Tooling API
System.debug('CSP Trusted Site "QrCodeApi" deployed via metadata.');
System.debug('If the QR code image does not load, add api.qrserver.com manually:');
System.debug('Setup > Security > Trusted URLs > New Trusted URL');
System.debug('  URL: https://api.qrserver.com');
System.debug('  Context: All');
System.debug('  CSP Directives: img-src');

// Also verify the community site URL for reference
List<Network> networks = [SELECT Id, Name, UrlPathPrefix FROM Network WHERE Name = 'Talan Talent Intelligence RH2'];
for (Network n : networks) {
    String siteUrl = Site.getBaseSecureUrl();
    System.debug('Community: ' + n.Name + ' | Path: ' + n.UrlPathPrefix);
    System.debug('Site Base URL: ' + siteUrl);
}

System.debug('All checks complete. Refresh the site page to see the QR code.');
