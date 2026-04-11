HttpRequest req = new HttpRequest();
req.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/connect/communities/0DBfj000001sohhGAA/publish');
req.setMethod('POST');
req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
req.setHeader('Content-Type', 'application/json');
req.setBody('{}');
HttpResponse res = new Http().send(req);
System.debug('Publish: ' + res.getStatusCode() + ' ' + res.getBody());
