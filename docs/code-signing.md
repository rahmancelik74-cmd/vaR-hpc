# Code signing policy

Status: the SignPath application has been submitted. Provider acceptance and
certificate access have not been confirmed, and no signed project release has
been published. The existing
portable CPU preview is unsigned. A checksum does not authenticate its publisher.

## Scope and roles

The project-owned targets are `Start Monte Carlo Lab.exe` and
`resources/bin/mc_var.exe`, built from this repository. Their ProductName is
`Monte Carlo Lab`; both ProductVersion values use the CMake project version.
Upstream Python and Microsoft runtime files retain their upstream licenses and
signatures; they must not be signed as project-owned code. Acceptance of the
bundled Microsoft runtime as system libraries must be resolved with the provider.

Repository maintainer: [rahmancelik74-cmd](https://github.com/rahmancelik74-cmd).
Proposed author, reviewer and signing approver: that repository owner. These are
proposed roles, not verified SignPath permissions. Before activation, the owner
must confirm the assignments and MFA for repository and SignPath access. Changes
from other contributors require maintainer review. Each signing request requires
a designated human approver; unattended development does not waive that step.

## Release controls

Only artifacts traceable to reviewed source and a successful exact-commit CI
build may enter signing. Sign the two owned EXEs before generating the final
package manifest, integrity hashes and ZIP checksum; verify returned signatures,
enforced product/version metadata and the final extracted package. Keep existing
release assets immutable and publish signed bytes under a distinct release asset.
No signing secrets, workflow integration or approval bypass are enabled now.

If accepted, publish the provider attribution and confirmed team roles required
by the [SignPath Foundation terms](https://signpath.org/terms) here and on the
download page. Provider sponsorship must not be represented as granted beforehand.
Acceptance and Windows trust/reputation outcomes are not guaranteed.

## Privacy policy

The application processes data through a service bound to the local loopback
interface. It has no telemetry or automatic remote uploads. Uploaded CSVs,
metadata, generated results and diagnostic records stay in the local per-user
workspace; browser downloads are user-requested. No external account is required
to run the package. Third-party runtimes execute locally within this application.
Opening repository/download links uses the user's browser and those sites' own
privacy policies. Building the package downloads upstream dependencies; this is
separate from running the distributed application.

To remove the portable application, stop it, remove its extracted folder and
archive or remove only its identified per-user folders as described in
[the portable guide](windows-portable.md). It installs no system service,
startup entry or firewall exception.
