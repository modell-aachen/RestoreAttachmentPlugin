# Plugin for Foswiki - The Free and Open Source Wiki, http://foswiki.org/

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

=pod

---+ package Foswiki::Plugins::RestoreAttachmentPlugin

When developing a plugin it is important to remember that
Foswiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %SYSTEMWEB%.InstalledPlugins for error messages.

__NOTE:__ Foswiki:Development.StepByStepRenderingOrder helps you decide which
rendering handler to use. When writing handlers, keep in mind that these may
be invoked on included topics. For example, if a plugin generates links to the
current topic, these need to be generated before the =afterCommonTagsHandler=
is run. After that point in the rendering loop we have lost the information
that the text had been included from another topic.

__NOTE:__ Not all handlers (and not all parameters passed to handlers) are
available with all versions of Foswiki. Where a handler has been added
the POD comment will indicate this with a "Since" line
e.g. *Since:* Foswiki::Plugins::VERSION 1.1

Deprecated handlers are still available, and can continue to be used to
maintain compatibility with earlier releases, but will be removed at some
point in the future. If you do implement deprecated handlers, then you can
do no harm by simply keeping them in your code, but you are recommended to
implement the alternative as soon as possible.

See http://foswiki.org/Download/ReleaseDates for a breakdown of release
versions.

=cut


package Foswiki::Plugins::RestoreAttachmentPlugin;

require Foswiki;
require Foswiki::UI;
require Foswiki::Sandbox;
require Foswiki::OopsException;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::UI;
use Foswiki::Func;
use Foswiki::Plugins;   # For the API version

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package. This should always be in the format
# $Rev: 8536 $ so that Foswiki can determine the checked-in status of the
# extension.
our $VERSION = '$Rev: 8536 $';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
our $RELEASE = "1.1";

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'Restoring Attachments';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
#
# %SYSTEMWEB%.DevelopingPlugins has details of how to define =$Foswiki::cfg=
# entries so they can be used with =configure=.
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Plugin correctly initialized
    return 1;
}

sub restoreAttachment {
    my $session = shift;

    my $query = $session->{request};

    my $topic   = $session->{topicName};
    my $webName = $session->{webName};

    my $fileName;
    my $pathInfo;

    if (defined($ENV{REDIRECT_STATUS}) &&
        $ENV{REDIRECT_STATUS} != 200 &&
        defined($ENV{REQUEST_URI}))
    {
        # this is a redirect - can be used to make 404,401 etc URL's
        # more foswiki tailored and is also used in TWikiCompatibility
        $pathInfo = $ENV{REQUEST_URI};
        # ignore parameters, as apache would.
        $pathInfo =~ s/^(.*)(\?|#).*/$1/;
        $pathInfo =~ s|$Foswiki::cfg{PubUrlPath}||; #remove pubUrlPath
    }
    elsif ( defined( $query->param('filename') ) ) {
        # Filename is an attachment to the topic in the standard path info
        # /Web/Topic?filename=Attachment.gif
        $fileName = $query->param('filename');
    }
    else {
        # This is a standard path extended by the attachment name e.g.
        # /Web/Topic/Attachment.gif
        $pathInfo = $query->path_info();
    }

    if ($pathInfo) {
        my @path = split( /\/+/, $pathInfo );
        shift(@path) unless ($path[0]);   # remove leading empty string

        # work out the web, topic and filename
        $webName = '';
        while ( $path[0]
                  && ($session->{store}->webExists($webName.$path[0]))) {
            $webName .= shift(@path).'/';
        }
        # The web name has been validated, untaint
        chop($webName); # trailing /
        $webName = Foswiki::Sandbox::untaintUnchecked($webName);

        # The next element on the path has to be the topic name
        $topic = shift(@path);
        if (!$topic) {
            throw Foswiki::OopsException(
                    'attention',
                    def    => 'no_such_attachment',
                    web    => $webName,
                    topic  => $topic || 'Unknown',
                    status => 404,
                    params => [ 'viewfile', '?' ]
                   );
        }
        # Topic has been validated
        $topic = Foswiki::Sandbox::untaintUnchecked($topic);
        # What's left in the path is the attachment name.
        $fileName = join('/', @path);
    }

    # According to SvenDowideit, you can't remove the /'s from the filename,
    # as there are directories below the pub/web/topic.
    #$fileName = Foswiki::Sandbox::sanitizeAttachmentName($fileName);
    $fileName = Foswiki::Sandbox::normalizeFileName($fileName);

    if ( !$fileName ) {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_attachment',
            web    => 'Unknown',
            topic  => 'Unknown',
            status => 404,
            params => [ 'viewfile', '?' ]
        );
    }

    #print STDERR "VIEWFILE: web($webName), topic($topic), file($fileName)\n";

    #Alex: time based query
    #Datei Revision auf Grund der Topic Zeit herausfinden
	my $rev = $query->param('rev');

    unless ( $fileName
        && $session->{store}->attachmentExists( $webName, $topic, $fileName ) )
    {
        throw Foswiki::OopsException(
            'attention',
            def    => 'no_such_attachment',
            web    => $webName,
            topic  => $topic,
            status => 404,
            params => [ 'viewfile', $fileName || '?' ]
        );
    }
    # Something is seriously wrong if any of these is tainted. If they are,
    # find out why and validate them at the input point.


    # TSA SMELL: Maybe could be less memory hungry if get a file handle
    # and set response body to it. This way engines could send data the
    # best way possible to each one
    my $fileContent = Foswiki::Func::readAttachment(
        $webName, $topic, $fileName, $rev);

    require File::Temp;
    my $tmpDir = Foswiki::Func::getWorkArea( 'RestoreAttachmentPlugin' );
    my $ft = new File::Temp(DIR => $tmpDir); # will be unlinked on destroy
#    my $ft = new File::Temp(); # will be unlinked on destroy
    # Ende

    my $fn = $ft->filename();
    binmode($ft);
    print $ft $fileContent;
    close($ft);

    #my $type   = _suffixToMimeType( $fileName );
    #my $length = length($fileContent);
    #my $dispo  = 'inline;filename=' . $fileName;

    my $error = Foswiki::Func::saveAttachment(
		$webName, $topic,
        $fileName,
            {
                dontlog     => !$Foswiki::cfg{Log}{upload},
                comment     => "Restored file",
                filedate    => time(),
                file        => $fn,
            });
     if ($error) {
			throw Foswiki::OopsException(
            'attention',
            def    => 'file not saved',
            web    => $webName,
            topic  => $topic,
            status => 404,
            params => [ 'viewfile', $fileName || '?' ]
        );
     }


    #Alex: Hier muss eigentlich der aktuelle Screen geupdatet werden...
    #returnRESTResult($session->{response}, 200, "Redirect $webName.$topic");
    Foswiki::Func::redirectCgiQuery( $query, Foswiki::Func::getScriptUrl($webName, $topic, 'view') )

}

sub _suffixToMimeType {
    my ( $attachment ) = @_;

    my $mimeType = 'text/plain';
    if ( $attachment && $attachment =~ /\.([^.]+)$/ ) {
        my $suffix = $1;
        my $types = Foswiki::readFile( $Foswiki::cfg{MimeTypesFileName} );
        if ($types =~ /^([^#]\S*).*?\s$suffix(?:\s|$)/im) {
            $mimeType = $1;
        }
    }
    return $mimeType;
}

sub returnRESTResult {
    my ( $response, $status, $text ) = @_;

    $response->header(
        -status  => $status,
        -type    => 'text/plain',
        -charset => 'UTF-8'
       );
    $response->print($text);

    print STDERR $text if ( $status >= 400 );
}


1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.