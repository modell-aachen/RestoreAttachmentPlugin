# ---+ Extensions
# ---++ RestoreAttachmentPlugin
# **PERL H**
# This setting is required to enable executing the compare script from the bin directory
$Foswiki::cfg{SwitchBoard}{restore} = {
    package  => 'Foswiki::Plugins::RestoreAttachmentPlugin',
    function => 'restoreAttachment',
    context  => { restoring => 1
                },
    };
1;