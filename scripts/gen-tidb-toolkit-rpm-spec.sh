if [ "$1" != "" ]; then
  VERSION=$1
else
  VERSION="master"
fi

cat << EOF
%global __os_install_post /usr/lib/rpm/brp-compress %{nil}
%global __spec_install_post %{nil}
%global debug_package %{nil}

Name:           tidb-toolkit
Version:        $VERSION
Release:        1%{?dist}
Summary:        A Collection of tools to enhance&manage TiDB cluster
License:        Apache License 2.0
Group:          Applications/Databases
URL:            https://github.com/pingcap/tidb

Source0:        bin
Source1:        config
Source2:        service

Requires:       systemd
Requires(pre):  shadow-utils
Requires(post): systemd

%description
* TiDB-Lightning is a tool for fast full import of large amounts of data into a TiDB cluster. Currently, we support reading SQL dump exported via mydumper.
* pd-tso-bench is a tool to benchmark GetTS performance.
* tikv-importer is a front-end to help ingesting large number of KV pairs into a TiKV cluster
* sync_diff_inspector is a tool for comparing two databases' data and outputting a brief report about the differences.

%prep

%build

%install
%{__mkdir} -p \$RPM_BUILD_ROOT%{_bindir}
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/tidb-lightning
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/sync_diff_inspector
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/tikv-importer
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/tidb-lightning
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/tikv-importer
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/sync_diff_inspector

%{__install} -D -p -m 0755 %{_sourcedir}/bin/tidb-lightning  \$RPM_BUILD_ROOT%{_bindir}/tidb-lightning
%{__install} -D -p -m 0755 %{_sourcedir}/bin/tidb-lightning-ctl  \$RPM_BUILD_ROOT%{_bindir}/tidb-lightning-ctl
%{__install} -D -m 0644 %{_sourcedir}/config/tidb-lightning/tidb-lightning.toml \$RPM_BUILD_ROOT%{_sysconfdir}/tidb-lightning/tidb-lightning.toml
%{__install} -D -m 0644 %{_sourcedir}/service/tidb-lightning.service \$RPM_BUILD_ROOT%{_unitdir}/tidb-lightning.service

%{__install} -D -p -m 0755 %{_sourcedir}/bin/tikv-importer \$RPM_BUILD_ROOT%{_bindir}/tikv-importer
%{__install} -D -m 0644 %{_sourcedir}/config/tikv-importer/tikv-importer.toml \$RPM_BUILD_ROOT%{_sysconfdir}/tikv-importer/tikv-importer.toml
%{__install} -D -m 0644 %{_sourcedir}/service/tikv-importer.service \$RPM_BUILD_ROOT%{_unitdir}/tikv-importer.service

%{__install} -D -p -m 0755 %{_sourcedir}/bin/sync_diff_inspector \$RPM_BUILD_ROOT%{_bindir}/sync_diff_inspector
%{__install} -D -m 0644 %{_sourcedir}/config/sync_diff_inspector/config.toml \$RPM_BUILD_ROOT%{_sysconfdir}/sync_diff_inspector/config.toml
%{__install} -D -m 0644 %{_sourcedir}/config/sync_diff_inspector/config_sharding.toml \$RPM_BUILD_ROOT%{_sysconfdir}/sync_diff_inspector/config_sharding.toml

%{__install} -D -p -m 0755 %{_sourcedir}/bin/pd-tso-bench \$RPM_BUILD_ROOT%{_bindir}/pd-tso-bench

%clean
rm -rf $RPM_BUILD_ROOT

%pre
getent group  tidb >/dev/null || groupadd -r tidb
getent passwd tidb >/dev/null || useradd -r -M -g tidb -s /sbin/nologin -d /var/lib/tidb tidb
exit 0

%post
%systemd_post tidb-lightning.service
%systemd_post tikv-importer.service

%preun
%systemd_preun tidb-lightning.service
%systemd_preun tikv-importer.service

%postun
%systemd_postun_with_restart tidb-lightning.service

%files
%{_bindir}/tidb-lightning
%{_bindir}/tidb-lightning-ctl
%{_unitdir}/tidb-lightning.service
%config(noreplace) %{_sysconfdir}/tidb-lightning/tidb-lightning.toml
%dir %{_sysconfdir}/tidb-lightning
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/tidb-lightning
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/tidb-lightning

%{_bindir}/tikv-importer
%{_unitdir}/tikv-importer.service
%config(noreplace) %{_sysconfdir}/tikv-importer/tikv-importer.toml
%dir %{_sysconfdir}/tikv-importer
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/tikv-importer
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/tikv-importer

%{_bindir}/sync_diff_inspector
%config(noreplace) %{_sysconfdir}/sync_diff_inspector/config_sharding.toml
%config(noreplace) %{_sysconfdir}/sync_diff_inspector/config.toml
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/sync_diff_inspector
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/sync_diff_inspector

%{_bindir}/pd-tso-bench

%license LICENSE

%changelog
EOF
