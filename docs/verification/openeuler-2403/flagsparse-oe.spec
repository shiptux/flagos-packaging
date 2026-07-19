%global debug_package %{nil}

Name:           python3-flagsparse
Version:        1.0.0
Release:        1%{?dist}
Summary:        FlagSparse — sparse compute kernels for FlagOS

License:        Apache-2.0
URL:            https://github.com/flagos-ai/FlagSparse
Source0:        flagsparse-%{version}.tar.gz
BuildArch:      noarch
BuildRequires:  python3-devel
BuildRequires:  python3-setuptools >= 60
BuildRequires:  python3-wheel
BuildRequires:  python3-pip

%description
Sparse matrix operators (SpMM, SpMV, sampled dense-dense) for
FlagOS-supported accelerators.

# openEuler 24.03 has no pyproject-rpm-macros; use pip wheel/install
# directly instead of the %%pyproject_* macro family.

%prep
%autosetup -n flagsparse-%{version}

%build
%{__python3} -m pip wheel --no-deps --no-build-isolation --wheel-dir dist .

%install
%{__python3} -m pip install --no-deps --no-index --no-warn-script-location \
    --root %{buildroot} dist/*.whl

%check
PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=%{buildroot}%{python3_sitelib} \
    %{__python3} -c "import importlib.util; s = importlib.util.find_spec('flagsparse'); assert s and s.origin, 'flagsparse not findable'; print('OK: flagsparse at', s.origin)"

%files
%license LICENSE
%{python3_sitelib}/flagsparse/
%{python3_sitelib}/flagsparse-%{version}.dist-info/

%changelog
* Sun Jul 05 2026 FlagOS Contributors <contact@flagos.io> - 1.0.0-1
- openEuler 24.03 adaptation of the upstream Fedora-style spec
  (pyproject-rpm-macros unavailable; pip-based build/install).
