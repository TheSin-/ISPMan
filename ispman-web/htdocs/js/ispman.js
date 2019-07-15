function whois(domain){
        whoisWin=window.open("/cgi-bin/whois.cgi?"+domain, "WHOIS", "toolbar=no,location=no,status=no,scrollbars=yes,resizable=yes,width=640,height=480,left=0,top=0");
        whoisWin.opener=self;
        whoisWin.focus();
}

function CheckDomainForm(form) {
    if ((form.ispmanDomainOwner.value=="") || (form.ispmanDomainCustomer.value=="")) {
        alert("Please enter owner and customer before submitting");
             return false;
    } else {
      	   return true;
    }
}
