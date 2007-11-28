#!/usr/local/bin/perl
# Deletes a mailbox user, based on command-line parameters

package virtual_server;
if (!$module_name) {
	$main::no_acl_check++;
	$ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
	$ENV{'WEBMIN_VAR'} ||= "/var/webmin";
	if ($0 =~ /^(.*\/)[^\/]+$/) {
		chdir($1);
		}
	chop($pwd = `pwd`);
	$0 = "$pwd/delete-user.pl";
	require './virtual-server-lib.pl';
	$< == 0 || die "delete-user.pl must be run as root";
	}

# Parse command-line args
while(@ARGV > 0) {
	local $a = shift(@ARGV);
	if ($a eq "--domain") {
		$domain = shift(@ARGV);
		}
	elsif ($a eq "--user") {
		$username = lc(shift(@ARGV));
		}
	else {
		&usage();
		}
	}

# Make sure all needed args are set
$domain && $username || &usage();
$d = &get_domain_by("dom", $domain);
$d || usage("Virtual server $domain does not exist");
&lock_user_db();
@users = &list_domain_users($d);
($user) = grep { $_->{'user'} eq $username ||
		 &remove_userdom($_->{'user'}, $d) eq $username } @users;
$user || usage("No user named $username was found in the server $domain");
$user->{'domainowner'} && usage("The user $username is the owner of server $domain, and so cannot be deleted");

if (!$user->{'nomailfile'}) {
	# Remove mail file
	&delete_mail_file($user);
	}

# Delete simple autoreply file
if (defined(&get_simple_alias)) {
	$simple = &get_simple_alias($d, $user);
	&delete_simple_autoreply($d, $simple) if ($simple);
	}

# Delete the user, his virtusers and aliases
&delete_user($user, $d);

if (!$user->{'nocreatehome'}) {
	# Remove home directory
	&delete_user_home($user, $d);
	}

# Delete in plugins
foreach $f (@mail_plugins) {
	&plugin_call($f, "mailbox_delete", $user, $d);
	}

# Delete in other modules
if ($config{'other_users'}) {
	&foreign_call($usermodule, "other_modules",
		      "useradmin_delete_user", $user);
	}

&run_post_actions();

print "User $user->{'user'} deleted successfully\n";
&unlock_user_db();

sub usage
{
print "$_[0]\n\n" if ($_[0]);
print "Deletes an existing mail, FTP or database user from a Virtualmin domain.\n";
print "\n";
print "usage: delete-user.pl    --domain domain.name\n";
print "                         --user username\n";
exit(1);
}

