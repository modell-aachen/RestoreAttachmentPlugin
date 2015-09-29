# ---+ Extensions
# ---++ RestoreAttachmentPlugin
# Configuration values for RestoreAttachmentPlugin

# **PERL H**
$Foswiki::cfg{SwitchBoard}{restore} = {
    package  => 'Foswiki::Plugins::RestoreAttachmentPlugin',
    function => 'restoreAttachment',
    context  => { 'restoring' => 1 },
};