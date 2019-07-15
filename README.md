ISPMan 1.4
==================================

http://ispman.sourceforge.net


What is ISPMan?
------------------

ISPMan is a distributed system to manage components of ISP from a central management interface. 
These components run accross frontend and backend servers.

Front end servers are the machines that are directly visible to your internet users. For example your web (eg. Apache), SMTP (eg. Postfix), DNS (eg. Bind) servers while backend servers can be Mailbox servers (eg. Cyrus IMAP server), Fileservers, database servers etc.

ISPMan is designed to be scalable. 
_Example:_
You may start with a single server to manage user's mailboxes and add more as you grow. ISPMan can manage this and allow you to create user's accounts and mailboxes on different servers. This does not affect the user at all but allows the system administrator to balance the load of mails on different machines.

ISPMan is writtin mostly in Perl and is based on four major components. All these components are based on open standards and are easily customizable.

* **LDAP-directory** works as a central registry of information about users, hosts, dns, processes etc. All information related to resources is kept in this directory.

The LDAP directory can be replicated to multiple machines to balance the load.

* **ISPMan-webinterface** is an intuitive Iinterface to manage informations about your ISP infrastructure. This interface allows you to edit your LDAP registry to change different informations about your resources such as adding a new domain, deleting a user etc.
The interface can run on http or https and is only available after successful authentification as an ISPMan admin. Access control to this interface can also be limited to designated IP addresses either via Apache access control functions or via ISPMan ACL.

* **ISPMan-agent** is a component of ISPMan that runs on hosts taking part in the ISP, these agents read the LDAP directory for processes assigned to them and take appropriate actions 
Example : create directory for new domains, create mailbox for users, etc. These agents are a very important part of the system and are should be run continuously. 
The agents are run via a fault taulerant services manager called « daemontools » that makes sure that the agents recovers immediately in case of any failure.

* **ISPMan-customer-control-panel** is an interface targeted towards customers (domain owners). Using this interface the domain owners can manage their own dns, webserver settings, users, mailing lists, access control etc.
