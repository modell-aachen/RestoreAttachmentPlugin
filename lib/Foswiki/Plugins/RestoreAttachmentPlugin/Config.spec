# ---+ Extensions
# ---++ RestoreAttachmentPlugin
# Configuration values for RestoreAttachmentPlugin

# **PERL HIDDEN**
$Foswiki::cfg{SwitchBoard}{restore} = {
    package  => 'Foswiki::Plugins::RestoreAttachmentPlugin',
    function => 'restoreAttachment',
    context  => { 'restoring' => 1 },
};
