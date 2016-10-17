#define buildid .

%define debug_package %{nil}

Name:		i7z
Version:	git93
Release:	1%{?buildid}%{?dist}
Summary:	A better i7 (and now i3, i5) reporting tool for Linux.

Provides:	%{name} = %{version}-%{release}
Provides:	%{name}-%{_target_cpu} = %{version}-%{release}

License:	GPLv2+
URL:		https://github.com/ajaiantilal/i7z
Source0:	%{name}-%{version}.tar.xz

BuildRequires:	ncurses-devel
#BuildRequires:	qt-devel

%description
A better i7 (and now i3, i5) reporting tool for Linux.

%prep
%setup -q -n %{name}-%{version} -c
%{__mv} %{name} %{name}-%{version}-%{release}.%{_target_cpu}

%build
pushd %{name}-%{version}-%{release}.%{_target_cpu} > /dev/null
%{__make} -s %{?_smp_mflags}
popd > /dev/null

%install
pushd %{name}-%{version}-%{release}.%{_target_cpu} > /dev/null
%{__make} -s DESTDIR=%{buildroot} install
%{__rm} -fr %{buildroot}%{_datadir}/doc
popd > /dev/null

%files
%doc %{name}-%{version}-%{release}.%{_target_cpu}/README.txt
%{_sbindir}/%{name}*
%{_mandir}/man[1-8]/%{name}*

%changelog

