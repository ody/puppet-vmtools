# Author: Cody Herriges
# Pulls a selection of packages from a full Centos 5 mirror and
# drops the packages into a requested location on the local machine
# if any packages are updated it then runs createrepo to generate
# a local yum repo.  The local repos are meant to allow PuppetMaster
# trainings to be ran in the event that internet connectivity is an
# issue.
#
# All package patterns in each local repo need to currently be with in the
# same resource.  This is due to the method of retrieving and cleaning
# up packages; each resource declaration is going to issues a `rsync
# --delete` with means that you will only get packages from the final
# resource that runs.  Suboptimal, yes and I think I am going to solve
# this with a ruby manifest at some point.
#
# Example:
#   pkgsync { "base_pkgs":
#     pkglist  => "httpd*\nperl-DBI*\nlibart_lgpl*\napr*\nruby-rdoc*\nntp*\n",
#     repopath => "/var/yum/mirror/centos/5/os/i386",
#     source   => "::centos/5/os/i386/CentOS/",
#     notify   => Repobuild["base"]
#   }
#
#   repobuild { "base":
#     repopath => "${base}/mirror/centos/5/os/i386",
#   }

define pkgsync ($pkglist = $name, $source, $server = "mirrors.cat.pdx.edu", $syncer = "rsync", $syncops = "-rltDvzPH --delete --delete-after", $repopath) {

  file { "/tmp/${name}list":
    content => "${pkglist}",
    mode     => 644,
    owner    => puppet,
    group    => puppet,
    notify   => Exec["get_${name}"],
  }

  file { [ "${repopath}", "${repopath}/RPMS" ]:
    ensure => directory,
    mode   => 644,
    owner  => puppet,
    group  => puppet,
  }

  exec { "get_${name}":
    command => "${syncer} ${syncops} --include-from=/tmp/${name}list  --exclude=* ${server}${source} ${repopath}/RPMS",
    user    => puppet,
    group   => puppet,
    path    => "/usr/bin:/bin",
    onlyif  => "${syncer} ${syncops} -n --include-from=/tmp/${name}list  --exclude=* ${server}${source} ${repopath}/RPMS | grep 'rpm$'",
    require => [ File["${repopath}/RPMS"], File["/tmp/${name}list"] ],
  }
}


define repobuild ($repopath, $repoer = "createrepo", $repoops = "-C --update -p") {

  exec { "${name}_build":
    command     => "${repoer} ${repoops} ${repopath}",
    user        => puppet,
    group       => puppet,
    path        => "/usr/bin:/bin",
    refreshonly => true,
  }

  file { "/etc/yum.repos.d/${name}.repo":
    content => "[${name}]\nname=Locally stored packages for ${name}\nbaseurl=file:///var/yum/${repopath}\nenabled=1\ngpgcheck=0",
    require => Exec["${name}_build"],
  }

}

class localpm {

  $base = "/var/yum"

  $directories = [ "${base}",
                   "${base}/mirror",
                   "${base}/mirror/epel",
                   "${base}/mirror/epel/5",
                   "${base}/mirror/epel/5/local",
                   "${base}/mirror/centos",
                   "${base}/mirror/centos/5",
                   "${base}/mirror/centos/5/os",
                   "${base}/mirror/centos/5/updates",
                   "${base}/mirror/puppetlabs",
                   "${base}/mirror/puppetlabs/local",
                   "${base}/mirror/puppetlabs/local/base", ]

  File { mode => 644, owner => puppet, group => puppet }

  file { $directories:
    ensure => directory,
    recurse => true,
  }

  pkgsync { "base_pkgs":
    pkglist  => "httpd*\nperl-DBI*\nlibart_lgpl*\napr*\nruby-rdoc*\nntp*\nbluez-libs*\nbluez-utils*\n",
    repopath => "${base}/mirror/centos/5/os/i386",
    source   => "::centos/5/os/i386/CentOS/",
    notify   => Repobuild["base_local"]
  }

  repobuild { "base_local":
    repopath => "${base}/mirror/centos/5/os/i386",
  }

  pkgsync { "updates_pkgs":
    pkglist  => "mysql*\npostgresql-libs*\n",
    repopath => "${base}/mirror/centos/5/updates/i386",
    source   => "::centos/5/updates/i386/RPMS/",
    notify   => Repobuild["updates_local"]
  }

  repobuild { "updates_local":
    repopath => "${base}/mirror/centos/5/updates/i386",
  }

  pkgsync { "epel_pkgs":
    pkglist  => "rubygems*\nrubygem-rake*\nruby-RRDtool*\nrrdtool-ruby*\nrubygem-sqlite3-ruby*\nrubygem-rails*\nrubygem-activesupport*\nrubygem-actionmailer*\nrubygem-activeresource*\nrubygem-actionpack*\nrubygem-activerecord*\nmysql*\nperl-DBD-MySQL*\nruby-mysql*\n",
    repopath => "${base}/mirror/epel/5/local/i386",
    source   => "::epel/5/i386/",
    notify   => Repobuild["epel_local"]
  }

  repobuild { "epel_local":
    repopath => "${base}/mirror/epel/5/local/i386",
  }

  pkgsync { "puppetlabs_pkgs":
    pkglist  => "puppet-dashboard*\n",
    repopath => "${base}/mirror/puppetlabs/local/base/i386",
    source   => "::packages/yum/base",
    server   => "yum.puppetlabs.com",
    notify   => Repobuild["puppetlabs_local"],
  }

  repobuild { "puppetlabs_local":
    repopath => "${base}/mirror/puppetlabs/local/base/i386",
  }

}

include localpm
