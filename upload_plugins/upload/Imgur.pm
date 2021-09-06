#! /usr/bin/env perl
###################################################
#
#  Copyright (C) 2008-2013 Mario Kemper <mario.kemper@gmail.com>
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
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
###################################################

package Imgur;

use lib $ENV{'SHUTTER_ROOT'}.'/share/shutter/resources/modules';

use utf8;
use strict;
use POSIX qw/setlocale/;
use Locale::gettext;
use Glib qw/TRUE FALSE/;
use MIME::Base64;

use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);

my $d = Locale::gettext->domain("shutter-upload-plugins");
$d->dir( $ENV{'SHUTTER_INTL'} );

my %upload_plugin_info = (
	'module'        => "Imgur",
	'url'           => "http://imgur.com/",
	'registration'  => "https://imgur.com/register",
	'description'   => $d->get( "Imgur is used to share photos with social networks and online communities, and has the funniest pictures from all over the Internet" ),
	'supports_anonymous_upload'	 => TRUE,
	'supports_authorized_upload' => FALSE,
	'supports_oauth_upload' => TRUE,
);

binmode( STDOUT, ":utf8" );
if ( exists $upload_plugin_info{$ARGV[ 0 ]} ) {
	print $upload_plugin_info{$ARGV[ 0 ]};
	exit;
}

sub debug_info {
	print @_;
}
###################################################

sub new {
	my $class = shift;

	#call constructor of super class (host, debug_cparam, shutter_root, gettext_object, main_gtk_window, ua)
	my $self = $class->SUPER::new( shift, shift, shift, shift, shift, shift );

	bless $self, $class;
	return $self;
}

sub init {
	my $self = shift;
	my $username = shift;

	#do custom stuff here
	use JSON;
	use LWP::UserAgent;
	use HTTP::Request::Common;
	use Path::Class;

	$self->{_config} = { };
	$self->{_config_file} = file($ENV{'HOME'}, '.imgur-api-config');
	
	$self->load_config;
	if ($username eq $d->get("OAuth"))
	{
		return $self->connect;
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

sub load_config {
	my $self = shift;
	
	if (-f $self->{_config_file}) {
		debug_info "Imgur config file:" . $self->{_config_file} . '\n';
		eval {
			$self->{_config} = decode_json(slurp($self->{_config_file}));
		};
		if ($@) {
			debug_info "Imgur use default client_id:" . $@;
			$self->{_config}->{client_id} = '9490811e0906b6e';
			$self->{_config}->{client_secret} = '158b57f13e9a51f064276bd9e31529fb065f741e';
		}
	}
	else {
		debug_info "Imgur use default client_id";
		$self->{_config}->{client_id} = '9490811e0906b6e';
		$self->{_config}->{client_secret} = '158b57f13e9a51f064276bd9e31529fb065f741e';
	}

	return TRUE;
}

sub connect {
	my $self = shift;
	return $self->setup;
}

sub setup {
	my $self = shift;
	
	debug_info "refresh_token:" . $self->{_config}->{refresh_token};
	debug_info "client_id:" . $self->{_config}->{client_id};

	# 更新 access_token 操作 #
	my %params = (
		'client_id' => $self->{_config}->{client_id},
		'client_secret' => $self->{_config}->{client_secret},
		'grant_type' => 'refresh_token',
		'refresh_token' => $self->{_config}->{refresh_token},
	);

	my @params = (
		"https://api.imgur.com/oauth2/token",
		'Content' => [%params]
	);
	my $req = HTTP::Request::Common::POST(@params);

	my $client = LWP::UserAgent->new(
		'timeout'    => 20,
		'keep_alive' => 10,
		'env_proxy'  => 1,
	);
	my $rsp = $client->request($req);

	debug_info "Update token Result:" . $rsp->content;
	my $json = JSON->new();
	my $json_rsp = $json->decode($rsp->content);
	
	if (exists $json_rsp->{status} && $json_rsp->{status} ne 200) {
		return $self->setup;
	}
	$self->{_config}->{access_token} = $json_rsp->{access_token};
	$self->{_config}->{refresh_token} = $json_rsp->{refresh_token};
	
	$self->{_config_file}->openw->print(encode_json($self->{_config}));
	chmod 0600, $self->{_config_file};

	return TRUE;
}

sub upload {
	my ( $self, $upload_filename, $username, $password ) = @_;

	#store as object vars
	$self->{_filename} = $upload_filename;
	$self->{_username} = $username;
	$self->{_password} = $password;
	debug_info "upload_filename:" . $upload_filename;
	debug_info "client_id:" . $self->{_config}->{client_id};
	debug_info "access_token:" . $self->{_config}->{access_token};

	utf8::encode $upload_filename;
	utf8::encode $password;
	utf8::encode $username;

	my $client = LWP::UserAgent->new(
		'timeout'    => 60,
		'keep_alive' => 10,
		'env_proxy'  => 1,
	);

	eval {

		my $json = JSON->new();

		open( IMAGE, $upload_filename ) or die "$!";
		my $binary_data = do { local $/ = undef; <IMAGE>; };
		close IMAGE;
		my $encoded_image = encode_base64($binary_data);

		my %params = (
			'image' => $encoded_image,
		);

		my @params = (
			"https://api.imgur.com/3/image",
			'Content' => [%params]
		);
		my $req;
		if ($self->{_config}->{access_token}) {
			debug_info "upload by access_token!";
			$req = HTTP::Request::Common::POST(@params, 'Authorization' => 'Bearer ' . $self->{_config}->{access_token});
		}
		else {
			debug_info "Anonymous upload by client_id.";
			$req = HTTP::Request::Common::POST(@params, 'Authorization' => 'Client-ID ' . $self->{_config}->{client_id});
		}
		my $rsp = $client->request($req);

		my $json_rsp = $json->decode( $rsp->content );

		if ($json_rsp->{'status'} ne 200) {
			unlink $self->{_config_file};
			$self->{_links}{'status'} = '';
			if (exists $json_rsp->{'data'}->{'error'}) {
				$self->{_links}{'status'} .= $json_rsp->{'data'}->{'error'} . ': ';
			}
			$self->{_links}{'status'} .= $d->get("Maybe you or Imgur revoked or expired an access token. Please close this dialog and try again. Your account will be re-authenticated the next time you upload a file.");
			return %{ $self->{_links} };
		}

		$self->{_links}{'status'} = $json_rsp->{'status'};
		$self->{_links}->{'direct_link'} = $json_rsp->{'data'}->{'link'};
		$self->{_links}->{'delete_link'} = 'https://imgur.com/delete/' . $json_rsp->{'data'}->{'deletehash'};
		$self->{_links}->{'post_link'} = $json_rsp->{'data'}->{'link'};
		$self->{_links}->{'post_link'} =~ s/i\.imgur/imgur/;
		$self->{_links}->{'post_link'} =~ s/\.[^.]+$//;

	};
	if ($@) {
		$self->{_links}{'status'} = $@;
		#~ print "$@\n";
	}

	#and return links
	return %{ $self->{_links} };
}

1;
