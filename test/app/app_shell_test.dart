import 'package:coregrid_mobile/app/app_shell.dart';
import 'package:coregrid_mobile/shared/auth/me_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shellBranchesFor', () {
    test('Officer gets every tab', () {
      expect(shellBranchesFor('InventoryOfficer'), [
        ShellBranch.home,
        ShellBranch.verify,
        ShellBranch.workflows,
        ShellBranch.faults,
        ShellBranch.account,
      ]);
    });

    test('Staff never gets Verify or Workflows (SRS §3.4.1)', () {
      final tabs = shellBranchesFor('Staff');
      expect(tabs, [ShellBranch.home, ShellBranch.faults, ShellBranch.account]);
      expect(tabs, isNot(contains(ShellBranch.verify)));
      expect(tabs, isNot(contains(ShellBranch.workflows)));
    });

    test('unresolved role gets only Home and Account', () {
      expect(shellBranchesFor(null), [ShellBranch.home, ShellBranch.account]);
    });
  });

  test('MeProfile parses /api/me and derives display fields', () {
    final me = MeProfile.fromJson({
      'email': 'nimal@example.com',
      'given_name': 'Nimal',
      'family_name': 'Perera',
      'role': 'InventoryOfficer',
      'organization_name': 'Ministry of Health',
    });

    expect(me.fullName, 'Nimal Perera');
    expect(me.initials, 'NP');
    expect(me.roleName, 'Inventory Officer');
    expect(me.organizationName, 'Ministry of Health');
  });
}
