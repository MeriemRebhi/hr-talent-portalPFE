// Check Experience Cloud pages/routes
String networkId = '0DBfj000001sohhGAA';

// Query NavigationMenuItems related to this community
HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + 
    '/services/data/v62.0/connect/communities/' + networkId);
req.setMethod('GET');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
HttpResponse res = new Http().send(req);
System.debug('Community info: ' + res.getBody());

// Also check via Tooling API for the CustomTab / FlexiPage
HttpRequest req2 = new HttpRequest();
req2.setEndpoint(URL.getOrgDomainUrl().toExternalForm() +
    '/services/data/v62.0/tooling/query?q=SELECT+Id,DeveloperName,MasterLabel+FROM+FlexiPage+WHERE+DeveloperName+LIKE+\'%25echnique%25\'');
req2.setMethod('GET');
req2.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
HttpResponse res2 = new Http().send(req2);
System.debug('FlexiPages matching technique: ' + res2.getBody());

// Check for all community pages
HttpRequest req3 = new HttpRequest();
req3.setEndpoint(URL.getOrgDomainUrl().toExternalForm() +
    '/services/data/v62.0/tooling/query?q=SELECT+Id,DeveloperName,MasterLabel+FROM+FlexiPage+WHERE+Type=\'CommAppPage\'');
req3.setMethod('GET');
req3.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
HttpResponse res3 = new Http().send(req3);
System.debug('All Community Pages: ' + res3.getBody());
