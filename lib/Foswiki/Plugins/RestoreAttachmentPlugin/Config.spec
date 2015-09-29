#---+ Extensions
#---++ RestoreAttachmentPlugin
# Configuration values for RestoreAttachmentPlugin

# **PERL HIDDEN**
# This setting is required to enable executing the compare script from the bin directory
$Foswiki::cfg{SwitchBoard}{restore} = {
    package  => 'Foswiki::Plugins::RestoreAttachmentPlugin',
    function => 'restoreAttachment',
    context  => { restoring => 1
                },
    };
1;