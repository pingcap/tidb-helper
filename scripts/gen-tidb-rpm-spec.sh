if [ "$1" != "" ]; then
  VERSION=$1
else
  VERSION="master"
fi

cat << EOF
%global __os_install_post /usr/lib/rpm/brp-compress %{nil}
%global __spec_install_post %{nil}
%global debug_package %{nil}

Name:           tidb
Version:        $VERSION
Release:        1%{?dist}
Summary:        TiDB is a distributed NewSQL database compatible with MySQL protocol
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
TiDB is an open-source NewSQL database that supports Hybrid Transactional and Analytical Processing (HTAP) workloads. It is MySQL compatible and features horizontal scalability, strong consistency, and high availability.

TiDB features:
* Horizontal Scalability
* MySQL Compatible Syntax
* Distributed Transactions with Strong Consistency
* Cloud Native
* Minimize ETL
* High Availability

%prep

%build

%install
%{__mkdir} -p \$RPM_BUILD_ROOT%{_bindir}

%{__install} -D -p -m 0755 %{_sourcedir}/bin/tidb-server  \$RPM_BUILD_ROOT%{_bindir}/tidb-server
%{__install} -D -p -m 0755 %{_sourcedir}/bin/tidb-ctl  \$RPM_BUILD_ROOT%{_bindir}/tidb-ctl
%{__install} -D -m 0644 %{_sourcedir}/config/tidb/config.toml \$RPM_BUILD_ROOT%{_sysconfdir}/tidb/config.toml
%{__install} -D -m 0644 %{_sourcedir}/service/tidb-server.service \$RPM_BUILD_ROOT%{_unitdir}/tidb-server.service
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/tidb
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/tidb

%{__install} -D -p -m 0755 %{_sourcedir}/bin/tikv-server \$RPM_BUILD_ROOT%{_bindir}/tikv-server
%{__install} -D -p -m 0755 %{_sourcedir}/bin/tikv-ctl \$RPM_BUILD_ROOT%{_bindir}/tikv-ctl
%{__install} -D -m 0644 %{_sourcedir}/config/tikv/config.toml \$RPM_BUILD_ROOT%{_sysconfdir}/tikv/config.toml
%{__install} -D -m 0644 %{_sourcedir}/service/tikv-server.service \$RPM_BUILD_ROOT%{_unitdir}/tikv-server.service
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/tikv
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/tikv

%{__install} -D -p -m 0755 %{_sourcedir}/bin/pd-server \$RPM_BUILD_ROOT%{_bindir}/pd-server
%{__install} -D -p -m 0755 %{_sourcedir}/bin/pd-recover \$RPM_BUILD_ROOT%{_bindir}/pd-recover
%{__install} -D -p -m 0755 %{_sourcedir}/bin/pd-ctl \$RPM_BUILD_ROOT%{_bindir}/pd-ctl
%{__install} -D -m 0644 %{_sourcedir}/config/pd/config.toml \$RPM_BUILD_ROOT%{_sysconfdir}/pd/config.toml
%{__install} -D -m 0644 %{_sourcedir}/service/pd-server.service \$RPM_BUILD_ROOT%{_unitdir}/pd-server.service
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/pd
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/pd

%{__install} -D -p -m 0755 %{_sourcedir}/bin/etcdctl \$RPM_BUILD_ROOT%{_bindir}/etcdctl
%{__install} -D -p -m 0755 %{_sourcedir}/bin/binlogctl \$RPM_BUILD_ROOT%{_bindir}/binlogctl

%{__install} -D -p -m 0755 %{_sourcedir}/bin/arbiter \$RPM_BUILD_ROOT%{_bindir}/arbiter
%{__install} -D -m 0644 %{_sourcedir}/config/arbiter/arbiter.toml \$RPM_BUILD_ROOT%{_sysconfdir}/arbiter/arbiter.toml
%{__install} -D -m 0644 %{_sourcedir}/service/arbiter.service \$RPM_BUILD_ROOT%{_unitdir}/arbiter.service
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/arbiter
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/arbiter

%{__install} -D -p -m 0755 %{_sourcedir}/bin/drainer \$RPM_BUILD_ROOT%{_bindir}/drainer
%{__install} -D -m 0644 %{_sourcedir}/config/drainer/drainer.toml \$RPM_BUILD_ROOT%{_sysconfdir}/drainer/drainer.toml
%{__install} -D -m 0644 %{_sourcedir}/service/drainer.service \$RPM_BUILD_ROOT%{_unitdir}/drainer.service
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/drainer
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/drainer

%{__install} -D -p -m 0755 %{_sourcedir}/bin/pump \$RPM_BUILD_ROOT%{_bindir}/pump
%{__install} -D -m 0644 %{_sourcedir}/config/pump/pump.toml \$RPM_BUILD_ROOT%{_sysconfdir}/pump/pump.toml
%{__install} -D -m 0644 %{_sourcedir}/service/pump.service \$RPM_BUILD_ROOT%{_unitdir}/pump.service
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/pump
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/pump

%{__install} -D -p -m 0755 %{_sourcedir}/bin/reparo \$RPM_BUILD_ROOT%{_bindir}/reparo
%{__install} -D -m 0644 %{_sourcedir}/config/reparo/reparo.toml \$RPM_BUILD_ROOT%{_sysconfdir}/reparo/reparo.toml
%{__install} -D -m 0644 %{_sourcedir}/service/reparo.service \$RPM_BUILD_ROOT%{_unitdir}/reparo.service
%{__mkdir} -p \$RPM_BUILD_ROOT%{_sharedstatedir}/reparo
%{__mkdir} -p \$RPM_BUILD_ROOT%{_localstatedir}/log/reparo

%clean
rm -rf $RPM_BUILD_ROOT

%pre
getent group  tidb >/dev/null || groupadd -r tidb
getent passwd tidb >/dev/null || useradd -r -M -g tidb -s /sbin/nologin -d /var/lib/tidb tidb
exit 0

%post
%systemd_post tidb-server.service
%systemd_post tikv-server.service
%systemd_post pd-server.service
%systemd_post arbiter.service
%systemd_post drainer.service
%systemd_post pump.service

%preun
%systemd_preun tidb-server.service
%systemd_preun tikv-server.service
%systemd_preun pd-server.service
%systemd_preun arbiter.service
%systemd_preun drainer.service
%systemd_preun pump.service

%postun
%systemd_postun_with_restart tidb-server.service

%files
%{_bindir}/tidb-server
%{_bindir}/tidb-ctl
%{_unitdir}/tidb-server.service
%config(noreplace) %{_sysconfdir}/tidb/config.toml
%dir %{_sysconfdir}/tidb
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/tidb
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/tidb

%{_bindir}/tikv-server
%{_bindir}/tikv-ctl
%{_unitdir}/tikv-server.service
%config(noreplace) %{_sysconfdir}/tikv/config.toml
%dir %{_sysconfdir}/tikv
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/tikv
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/tikv

%{_bindir}/pd-server
%{_bindir}/pd-ctl
%{_bindir}/pd-recover
%{_unitdir}/pd-server.service
%config(noreplace) %{_sysconfdir}/pd/config.toml
%dir %{_sysconfdir}/pd
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/pd
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/pd

%{_bindir}/binlogctl
%{_bindir}/etcdctl

%{_bindir}/arbiter
%{_unitdir}/arbiter.service
%config(noreplace) %{_sysconfdir}/arbiter/arbiter.toml
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/arbiter
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/arbiter

%{_bindir}/drainer
%{_unitdir}/drainer.service
%config(noreplace) %{_sysconfdir}/drainer/drainer.toml
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/drainer
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/drainer

%{_bindir}/pump
%{_unitdir}/pump.service
%config(noreplace) %{_sysconfdir}/pump/pump.toml
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/pump
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/pump

%{_bindir}/reparo
%{_unitdir}/reparo.service
%config(noreplace) %{_sysconfdir}/reparo/reparo.toml
%dir %attr(0755, tidb, tidb) %{_sharedstatedir}/reparo
%dir %attr(0755, tidb, tidb) %{_localstatedir}/log/reparo

%doc README.md
%license LICENSE

%changelog
EOF
