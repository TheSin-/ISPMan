sub modifyTransport_task {
   my $params=shift;
   
   require "smtp.lib";
   
   modify_transport_map_entry($params->{'domain'}, $params->{'ispmanDomainMailDeliveryMethod'});
   
   return reload_postfix();
}
