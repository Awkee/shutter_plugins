#! /usr/bin/env perl
###################################################
#
#  Copyright (C) <year> <author> <<email>>
#
#  This file is part of Shutter.
#
#  Shutter is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  Shutter is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Shutter; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
###################################################
 
package SMMS;                                              #edit
 
use lib $ENV{'SHUTTER_ROOT'}.'/share/shutter/resources/modules';
 
use utf8;
use strict;
use POSIX qw/setlocale/;
use Locale::gettext;
use Glib qw/TRUE FALSE/;
use Data::Dumper;

use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);
 
my $d = Locale::gettext->domain("shutter-plugins");
$d->dir( $ENV{'SHUTTER_INTL'} );
 
my %upload_plugin_info = (
    'module'                        => "SMMS",                       #edit (must be the same as 'package')
    'url'                           => "https://sm.ms/",           #edit (the website's url)
    'registration'                  => "https://sm.ms/register",   #edit (a link to the registration page)
    'name'                          => "SMMS",                       #edit (the provider's name)
    'description'                   => "Upload screenshots to SM.MS",#edit (a description of the service)
    'supports_anonymous_upload'     => TRUE,                         #TRUE if you can upload *without* username/password
    'supports_authorized_upload'    => FALSE,                        #TRUE if username/password are supported (might be in addition to anonymous_upload)
    'supports_oauth_upload'         => FALSE,                        #TRUE if OAuth is used (see Dropbox.pm as an example)
);

sub debug_info {
	print @_;
}
 
binmode( STDOUT, ":utf8" );
if ( exists $upload_plugin_info{$ARGV[ 0 ]} ) {
    debug_info $upload_plugin_info{$ARGV[ 0 ]};
    exit;
}


#don't touch this
sub new {
    my $class = shift;
 
    #call constructor of super class (host, debug_cparam, shutter_root, gettext_object, main_gtk_window, ua)
    my $self = $class->SUPER::new( shift, shift, shift, shift, shift, shift );
 
    bless $self, $class;
    return $self;
}
 
#load some custom modules here (or do other custom stuff)   
sub init {
    my $self = shift;
 
    use JSON;                   #example1
    use LWP::UserAgent;         #example2
    use HTTP::Request::Common;  #example3
    use HTTP::Headers;
    use Path::Class;

	$self->{_config} = { };
	$self->{_config_file} = file($ENV{'HOME'}, '.smms-api-config');
    if (-f $self->{_config_file}) {
        $self->{_config} = decode_json(slurp($self->{_config_file}));
        $self->{api_token} = $self->{_config}->{api_token};
    } else {
        debug_info "file ~/.smms-api-config not found!";
    }
    return TRUE;    
}
sub slurp {
    my $file = shift;
    open my $fh, '<', $file or return undef;
    local $/ = undef;
    my $cont = <$fh>;
    close $fh;
    return $cont;
}
#handle 
sub upload {
    my ( $self, $upload_filename, $username) = @_;

    my $api_token = $self->{_config}->{api_token};
    utf8::encode $upload_filename;
    utf8::encode $api_token;

    #store as object vars
    debug_info "upload_filename：" . $upload_filename;
    debug_info "API-TOKEN：" . $api_token;

    #examples related to the sub 'init'
    my $json_coder = JSON::XS->new;

    my $browser = LWP::UserAgent->new(
        'timeout'    => 20,
        'keep_alive' => 10,
    );
    
    #upload the file
    eval{
        #construct POST request 
        my $url = "https://sm.ms/api/v2/upload";
        $browser->timeout(30);
        $browser->agent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36');

        # [Authorization => "Basic " . $api_token,]
        my $res = $browser->post(
            $url,
            Content_Type => 'multipart/form-data',
            Content => { smfile => [$upload_filename] },
            Authorization => "Basic " . $api_token,
        );
        
        if( $res->is_success) {
            debug_info "image upload success!";
            debug_info "return：" . $res->content;
            my $json_data;
            $json_data = $json_coder->decode($res->content);
            if( $json_data->{success}) {
                #save links
                $self->{_links}->{'direct_link'} = $json_data->{data}->{url};
                $self->{_links}->{'delete_link'} = $json_data->{data}->{delete};
                $self->{_links}->{'Markdown'} = "![" . $json_data->{data}->{filename} . "](" . $json_data->{data}->{url} . ")";
            } else {
                if ($json_data->{code} == "image_repeated") {
                    debug_info "image_repeated: " . $json_data->{images} ;
                    $self->{_links}->{'repeated_direct_link'} = $json_data->{images};
                } else {
                    debug_info "code:" .  $json_data->{code};
                    debug_info "message:" .  $json_data->{message};
                }
            }

            #set success code (200)
            $self->{_links}{'status'} = 200;
        } else{
            debug_info "image upload failed!";
            debug_info $res->status_line;
        }
    };
    if($@){
        $self->{_links}{'status'} = $@;
        debug_info "status:" . $@;
    }
     
    #and return links
    return %{ $self->{_links} };
}
 
#you are free to implement some custom subs here, but please make sure they don't interfere with Shutter's subs
#hence, please follow this naming convention: _<provider>_sub (e.g. _imageshack_convert_x_to_y)
 
 
1;