# mp4-stitch.spec

%define name	mp4-stitch
%define version	1.0
%define release	1.dlts%{?dist}
%define dlibdir	/usr/local/dlib/%{name}

Summary:	Stitch mp4 files for HIDVL AD project.
Name:		%{name}
Version:	%{version}
Release:	%{release}
License:	NYU DLTS
Vendor:		NYU DLTS (rasan@nyu.edu)
Group:		Applications/Multimedia
URL:		https://v1.home.nyu.edu/svn/dlib/hidvl-ad/%{name}
BuildRoot:	%{_tmppath}/%{name}-root
BuildArch:	noarch

%description
%{summary}

%prep

%build

%install
rm -rf %{buildroot}

svn export %{url}/tags/%{version} %{buildroot}%{dlibdir}
find %{buildroot}%{dlibdir} -type d | xargs chmod 0755
find %{buildroot}%{dlibdir} -type f | xargs chmod 0644
chmod 0755 %{buildroot}%{dlibdir}/bin/*

mkdir -p %{buildroot}%{_bindir}
ln -s ../..%{dlibdir}/bin/mp4-stitch.pl %{buildroot}%{_bindir}/mp4-stitch

%clean
rm -rf %{buildroot}

%files
%defattr(-, root, dlib)
%dir %{dlibdir}
%config(noreplace) %{dlibdir}/conf
%{dlibdir}/pause
%{dlibdir}/bin
%{dlibdir}/doc
%{_bindir}/*

%changelog
