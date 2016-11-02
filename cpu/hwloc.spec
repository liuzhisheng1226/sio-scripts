%define debug_package %{nil}

Name:		hwloc
Version:	git15b374a
Release:	1%{?buildid}%{?dist}
Summary:	Portable Hardware Locality - portable abstraction of hierarchical architectures
License:	BSD-2-Clause
URL:		https://www.open-mpi.org/projects/hwloc/

Provides:	%{name} = %{version}-%{release}
Provides:	%{name}-%{_target_cpu} = %{version}-%{release}

BuildRequires:	autoconf >= 2.63, automake >= 1.11, libtool >= 2.2.6
BuildRequires:	libpciaccess-devel, pciutils-devel, numactl-devel
BuildRequires:	cairo-devel, doxygen, libX11-devel, ncurses-devel, libxml2-devel

Source0:	%{name}-master.zip

%description
The Portable Hardware Locality (hwloc) software package provides a portable
abstraction (across OS, versions, architectures, ...) of the hierarchical
topology of modern architectures, including NUMA memory nodes, sockets, shared
caches, cores and simultaneous multithreading. It also gathers various system
attributes such as cache and memory information as well as the locality of I/O
devices such as network interfaces, InfiniBand HCAs or GPUs.

%package devel
Summary:	Headers and shared development libraries for hwloc
Provides:	%{name}-devel = %{version}-%{release}
Requires:	%{name} = %{version}-%{release}

%description devel
Headers and shared development libraries for hwloc.

%prep
%setup -q -n %{name}-%{version} -c
%{__mv} %{name}-master %{name}-%{version}-%{release}.%{_target_cpu}

%build
pushd %{name}-%{version}-%{release}.%{_target_cpu} > /dev/null
./autogen.sh
%{configure} --disable-static
%{__make} V=1 %{?_smp_mflags}
popd > /dev/null

%install
pushd %{name}-%{version}-%{release}.%{_target_cpu} > /dev/null
%{__make} install DESTDIR=%{buildroot} INSTALL="%{__install} -p"
%{__mv} %{buildroot}%{_docdir}/%{name} %{buildroot}%{_docdir}/%{name}-%{version}
%{__cp} -p AUTHORS COPYING NEWS README VERSION %{buildroot}%{_docdir}/%{name}-%{version}
popd > /dev/null

%clean
%{__rm} -rf %{buildroot}

%post -p /sbin/ldconfig
%postun -p /sbin/ldconfig

%files
%defattr(-,root,root,-)
%docdir %{_docdir}/%{name}-%{version}
%doc %{_docdir}/%{name}-%{version}/*
%doc %{_mandir}/man1/hwloc*
%doc %{_mandir}/man1/lstopo*
%doc %{_mandir}/man7/hwloc*
%{_bindir}/hwloc*
%{_bindir}/lstopo*
%{_bindir}/netloc*
%{_sbindir}/hwloc*
%{_libdir}/libhwloc*so.*
%{_libdir}/libnetloc*so.*
%dir %{_datadir}/hwloc
%{_datadir}/applications/*.desktop
%exclude %{_libdir}/*.la
%exclude %{_datadir}/hwloc

%files devel
%defattr(-,root,root,-)
#%doc %{_mandir}/man3/hwloc*
#%doc %{_mandir}/man3/netloc*
#%doc %{_mandir}/man3/HWLOC*
#%doc %{_mandir}/man3/NETLOC*
%dir %{_includedir}/hwloc
%{_includedir}/hwloc/*
%{_includedir}/hwloc.h
#%{_includedir}/netloc*
%{_libdir}/libhwloc.so
%{_libdir}/libnetloc.so
%dir %{_libdir}/pkgconfig
%{_libdir}/pkgconfig/hwloc.pc
#%{_libdir}/pkgconfig/netloc.pc

%changelog

