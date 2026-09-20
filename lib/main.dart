import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

// ============================================================
// ENTRY POINT
// ============================================================
void main() {
  runApp(const MachiningApp());
}

// ------------------------------------------------------------
// DESIGN TOKENS
// Brand red pulled from the YG logo. Icon artwork is already
// colored, so cards just need a neutral backdrop for it to
// sit on.
// ------------------------------------------------------------
class _C {
  static const bg = Color(0xFFF6F1FA);
  static const card = Color(0xFFFFFFFF);
  static const cardAlt = Color(0xFFF1EDF6);
  static const textDark = Color(0xFF262330);
  static const textMuted = Color(0xFF7A7686);
  static const border = Color(0xFFE6E1EE);
  static const danger = Color(0xFFE5484D);
  static const brand = Color(0xFFED1C29); // YG red
  static const topStrip = Color(0xFFED1C29); // top strip accent — now red
}

// A thin blue strip shown at the very top of every screen, for a
// consistent brand accent across the whole app.
class TopStrip extends StatelessWidget implements PreferredSizeWidget {
  const TopStrip({super.key});
  @override
  Size get preferredSize => const Size.fromHeight(5);
  @override
  Widget build(BuildContext context) =>
      Container(color: _C.topStrip, height: 5);
}

// ------------------------------------------------------------
// MATERIAL DATABASE
// Specific cutting force (kc1.1) and the exponent (mc) that
// describes how cutting force changes with chip thickness, per
// machining material group. These are standard published
// reference values used across the industry (Kienzle model),
// not specific to any one tool brand.
// ------------------------------------------------------------
class MaterialSpec {
  final String group;
  final String description;
  final double rmMin;
  final double rmMax;
  final double kc11; // N/mm^2
  final double mc;
  const MaterialSpec(
      this.group, this.description, this.rmMin, this.rmMax, this.kc11, this.mc);
}

const List<MaterialSpec> kMaterials = [
  MaterialSpec(
      'P1, P6',
      'Non-alloyed / low-alloyed steel, C>0.25%, low-med strength',
      350,
      750,
      1500,
      0.21),
  MaterialSpec(
      'P2, P3, P4, P7, P14',
      'Unalloyed / low-alloyed steel, C>0.55%, not tempered',
      400,
      900,
      1700,
      0.25),
  MaterialSpec('P5, P8, P11, P12',
      'Low/high-alloyed steel, low tempering level', 750, 1100, 2000, 0.25),
  MaterialSpec('P15', 'Stainless ferritic/martensitic steel, tempered', 800,
      1400, 2200, 0.25),
  MaterialSpec('P9', 'Low/high-alloyed steel, medium tempering level', 1100,
      1400, 2500, 0.25),
  MaterialSpec('P10, P13', 'Low/high-alloyed steel, high tempering level', 1200,
      1600, 3000, 0.25),
  MaterialSpec('M1', 'Stainless steel, austenitic', 400, 900, 1800, 0.21),
  MaterialSpec('M3', 'Stainless steel, austenitic/ferritic + duplex', 600, 1000,
      2000, 0.21),
  MaterialSpec('M2', 'Stainless steel, austenitic, precipitation hardened (PH)',
      700, 1500, 2400, 0.21),
  MaterialSpec(
      'K1, K3, K7',
      'Grey cast iron + CGI + malleable cast iron, low strength',
      200,
      400,
      800,
      0.28),
  MaterialSpec(
      'K2, K5',
      'Ductile cast iron low strength + malleable higher strength',
      400,
      600,
      950,
      0.28),
  MaterialSpec(
      'K4', 'Grey cast iron, higher tensile strength', 300, 400, 1200, 0.28),
  MaterialSpec('K6', 'Ductile cast iron, high tensile + ADI, alloyed', 600, 800,
      1400, 0.28),
  MaterialSpec('N1', 'Aluminium wrought alloy, not hardened', 0, 0, 350, 0.25),
  MaterialSpec('N2', 'Aluminium wrought alloy, hardened', 0, 0, 600, 0.25),
  MaterialSpec(
      'N3', 'Cast aluminium alloy < 12% Si, not hardened', 0, 0, 600, 0.25),
  MaterialSpec('N4, N5', 'Cast aluminium alloy < 12% Si hardened / >= 12% Si',
      0, 0, 700, 0.25),
  MaterialSpec(
      'N7, N8, N9',
      'Pure copper, copper alloy (brass, bronze), low tensile',
      0,
      0,
      550,
      0.25),
  MaterialSpec('N10', 'High tensile copper alloy / bronze, high tensile', 0, 0,
      1000, 0.25),
  MaterialSpec(
      'S1', 'Heat-resistant alloy, iron-based, annealed', 0, 0, 2400, 0.25),
  MaterialSpec(
      'S2', 'Heat-resistant alloy, iron-based, hardened', 0, 0, 2500, 0.25),
  MaterialSpec('S6', 'Pure titanium', 0, 0, 1300, 0.25),
  MaterialSpec(
      'S7, S8', 'Titanium alloys, alpha / alpha-beta / beta', 0, 0, 1500, 0.25),
  MaterialSpec('S3', 'Heat-resistant alloy, nickel-cobalt based, annealed', 0,
      0, 2800, 0.25),
  MaterialSpec('S4', 'Heat-resistant alloy, nickel-cobalt based, hardened', 0,
      0, 2900, 0.25),
  MaterialSpec('S5', 'Heat-resistant alloy, nickel-cobalt based, cast', 0, 0,
      3000, 0.25),
  MaterialSpec('H1', 'Hardened steel, 46-52 HRC', 0, 0, 3000, 0.25),
  MaterialSpec('H2', 'Hardened steel, 52-58 HRC', 0, 0, 3700, 0.25),
  MaterialSpec('H3', 'Hardened steel, 58-62 HRC', 0, 0, 4300, 0.25),
  MaterialSpec('H4', 'Hardened cast iron, 50-60 HRC', 0, 0, 3500, 0.25),
  MaterialSpec(
      'O1, O2',
      'Thermoplastics and duroplasts, without abrasive fillers',
      0,
      0,
      150,
      0.20),
  MaterialSpec('O3, O4, O5', 'Fibre-reinforced plastics', 0, 0, 300, 0.30),
  MaterialSpec('O6', 'Graphite', 0, 0, 400, 0.25),
];

// Badge color per top-level material family (P/K/M/N/S/H/O), used
// as a small color tag in the picker so it reads at a glance like
// the reference material browser.
Color materialBadgeColor(String group) {
  final letter = group[0];
  switch (letter) {
    case 'P':
      return const Color(0xFFB9D6F0);
    case 'K':
      return const Color(0xFFE8D6E6);
    case 'M':
      return const Color(0xFFF2E9A8);
    case 'N':
      return const Color(0xFFD7E6D2);
    case 'S':
      return const Color(0xFFDDD7C0);
    case 'H':
      return const Color(0xFFE0E0E0);
    default:
      return const Color(0xFFC9CDD2);
  }
}

// ------------------------------------------------------------
// NAMED MATERIALS
// A much larger, real-world materials list (specific alloy
// designations with SAE/DIN cross-references), linked to the
// Walter machining groups above via each entry's resolved
// Walter group code. This lets the material picker be searched
// by an actual alloy name (e.g. "4140", "316", "Ti-6Al-4V")
// instead of only browsing the 33 generic categories.
// ------------------------------------------------------------
class NamedMaterial {
  final String name;
  final String subGroup;
  final String walterGroup; // resolves into kMaterials
  final String hardnessHrc;
  final String hardnessHrb;
  final String machinability;
  final String sae;
  final String din;
  final String
      en; // BS970 "EN" number (e.g. EN8) — only for high-confidence matches
  // Additional cross-reference standards (JIS/BS/AFNOR/SS/UNS/GOST/Brand),
  // pipe-separated, e.g. "JIS S10C | BS 040A10 | GOST 10". Optional — most
  // of the original hand-verified entries leave this blank; it's used by
  // the bulk-imported YG-1 VDI 3323 cross-reference tables. Searchable
  // alongside sae/din/en but not shown as a first-class column in the UI.
  final String refs;
  const NamedMaterial(
      this.name,
      this.subGroup,
      this.walterGroup,
      this.hardnessHrc,
      this.hardnessHrb,
      this.machinability,
      this.sae,
      this.din,
      this.en,
      [this.refs = '']);
}

// Looks up the underlying kc1.1 / mc spec for a named material.
MaterialSpec? materialSpecFor(NamedMaterial nm) {
  for (final m in kMaterials) {
    if (m.group == nm.walterGroup) return m;
  }
  return null;
}

const List<NamedMaterial> _kNamedMaterialsCore = [
  NamedMaterial('1112', 'Free Cutting Steel', 'P1, P6', '', '78-86', '100%',
      '1112', '10S20', ''),
  NamedMaterial('1140', 'Free Cutting Steel', 'P1, P6', '', '80-89', '70%',
      '1140', '35S20', ''),
  NamedMaterial('1144', 'Free Cutting Steel', 'P1, P6', '', '86-97', '76%',
      '1144', '44SMn28', ''),
  NamedMaterial('1151', 'Free Cutting Steel', 'P1, P6', '', '84-91', '66%',
      '1151', '45S20', ''),
  NamedMaterial('1213', 'Free Cutting Steel', 'P1, P6', '', '78-86', '136%',
      '1213', '9SMn28', ''),
  NamedMaterial('1215', 'Free Cutting Steel', 'P1, P6', '', '78-86', '136%',
      '1215', '9SMn36', 'EN1A'),
  NamedMaterial('12L14', 'Free Cutting Steel', 'P1, P6', '', '78-86', '170%',
      '12L14', '9SMnPb36', 'EN1A'),
  NamedMaterial('1006', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '56-70',
      '55%', '1006', 'St37', ''),
  NamedMaterial('1008', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '56-72',
      '60%', '1008', 'St12', ''),
  NamedMaterial('1010', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '60-74',
      '66%', '1010', 'Ck10', ''),
  NamedMaterial('1015', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '66-78',
      '75%', '1015', 'C15', ''),
  NamedMaterial('1018', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '70-80',
      '78%', '1018', 'C16E', ''),
  NamedMaterial('1020', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '70-80',
      '80%', '1020', 'C22', ''),
  NamedMaterial('1022', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '76-85',
      '80%', '1022', 'GS.20Mn5', ''),
  NamedMaterial('1025', 'Low Carbon Steel (0.1-0.25%)', 'P1, P6', '', '74-84',
      '80%', '1025', 'Ck25', ''),
  NamedMaterial('1035', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14', '',
      '84-93', '76%', '1035', 'C35', ''),
  NamedMaterial('1039', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14', '',
      '86-95', '70%', '1039', '40Mn4', 'EN8'),
  NamedMaterial('1040', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14', '',
      '86-95', '70%', '1040', 'C40', 'EN8'),
  NamedMaterial('1045', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14', '',
      '86-97', '65%', '1045', 'C45', ''),
  NamedMaterial('1049', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14', '',
      '89-99', '63%', '1049', 'Cm45', ''),
  NamedMaterial('1050', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14',
      '≤21', '89-100', '61%', '1050', 'Cf53', ''),
  NamedMaterial('1330', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14', '',
      '86-95', '65%', '1330', '28Mn6', ''),
  NamedMaterial('1335', 'Carbon Steel (0.26-0.50%)', 'P2, P3, P4, P7, P14', '',
      '89-97', '60%', '1335', '36Mn5', ''),
  NamedMaterial('1055', 'High Carbon Steel (0.51-1.0%)', 'P5, P8, P11, P12',
      '≤21', '91-100', '60%', '1055', 'Ck55', 'EN9'),
  NamedMaterial('1060', 'High Carbon Steel (0.51-1.0%)', 'P5, P8, P11, P12',
      '≤23', '≥93', '57%', '1060', 'C60', 'EN9'),
  NamedMaterial('1070', 'High Carbon Steel (0.51-1.0%)', 'P5, P8, P11, P12',
      '≤25', '≥95', '51%', '1070', 'Ck67', ''),
  NamedMaterial('1080', 'High Carbon Steel (0.51-1.0%)', 'P5, P8, P11, P12',
      '≤27', '≥97', '48%', '1080', 'Ck75', ''),
  NamedMaterial('1086', 'High Carbon Steel (0.51-1.0%)', 'P5, P8, P11, P12',
      '≤29', '≥99', '47%', '1086', 'Ck85', ''),
  NamedMaterial('1095', 'High Carbon Steel (0.51-1.0%)', 'P5, P8, P11, P12',
      '21-31', '≥100', '45%', '1095', 'Ck101', ''),
  NamedMaterial('4130', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '86-93', '69%', '4130', '25CrMo4', ''),
  NamedMaterial('32CrMo4', 'Low Alloyed Steel  (180 HB Max)',
      'P5, P8, P11, P12', '', '88-94', '72%', '', '32CrMo4', ''),
  NamedMaterial('4137', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '89-95', '74%', '4137', '34CrMo4', ''),
  NamedMaterial('4140', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '89-97', '61%', '4140', '42CrMo4', 'EN19'),
  NamedMaterial('4142', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '90-98', '60%', '4142', '41CrMo4', 'EN19'),
  NamedMaterial('4150', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '≤21', '93-100', '57%', '4150', '50CrMo4', ''),
  NamedMaterial('4340', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '≤25', '≥97', '57%', '4340', '35CrNiMo6', 'EN24'),
  NamedMaterial('5120', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '86-93', '84%', '5120', 'St52-3', ''),
  NamedMaterial('5130', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '88-94', '68%', '5130', '28Cr4', ''),
  NamedMaterial('5132', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '89-96', '70%', '5132', '34Cr4', ''),
  NamedMaterial('5140', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '90-97', '63%', '5140', '41Cr4', 'EN18'),
  NamedMaterial('52100', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '91-99', '40%', '52100', '100Cr6', 'EN31'),
  NamedMaterial('6150', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '93-99', '60%', '6150', '50CrV4', 'EN47'),
  NamedMaterial('40MnCr5', 'Low Alloyed Steel  (180 HB Max)',
      'P5, P8, P11, P12', '', '90-97', '60%', '', '40MnCr5', ''),
  NamedMaterial('8620', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '86-93', '66%', '8620', '21NiCrMo2', 'EN36'),
  NamedMaterial('8630', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '89-97', '59%', '8630', '27CrNiMo2', ''),
  NamedMaterial('A105', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '77-90', '66%', 'A105', 'C22-8', ''),
  NamedMaterial('A106GB', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '74-89', '73%', '', 'P235GH', ''),
  NamedMaterial('A234WPB', 'Low Alloyed Steel  (180 HB Max)',
      'P5, P8, P11, P12', '', '74-89', '73%', '', '', ''),
  NamedMaterial('A234WPL6', 'Low Alloyed Steel  (180 HB Max)',
      'P5, P8, P11, P12', '', '74-89', '73%', '', '', ''),
  NamedMaterial('A333G6', 'Low Alloyed Steel  (180 HB Max)', 'P5, P8, P11, P12',
      '', '74-89', '69%', '', 'P265GH', ''),
  NamedMaterial('A350LF2', 'Low Alloyed Steel  (180 HB Max)',
      'P5, P8, P11, P12', '', '77-90', '73%', '', '', ''),
  NamedMaterial('40CMD8', 'Tool Steel and High Alloy Steel (Annealed)',
      'P10, P13', '≤21', '93-100', '50%', '', '40CrMnMo7', ''),
  NamedMaterial('A2', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '≤21', '95-100', '42%', 'A2', 'X100CrMoV51', ''),
  NamedMaterial('A6', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '≤20', '93-100', '33%', 'A6', '', ''),
  NamedMaterial('D2', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '21-25', '≥100', '27%', 'D2', 'X165CrMoV12', ''),
  NamedMaterial('D3', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '21-25', '≥100', '23%', 'D3', 'X210Cr12', ''),
  NamedMaterial('H10', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '≤20', '93-100', '55%', 'H10', 'X32CrMoV33', ''),
  NamedMaterial('H11', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '≤20', '93-100', '55%', 'H11', 'X38CrMoV51', ''),
  NamedMaterial('H13', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '≤20', '93-100', '55%', 'H13', 'X40CrMoV51', ''),
  NamedMaterial('M2', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '22-26', '', '39%', 'M2', 'HS-6-5-2C', ''),
  NamedMaterial('M3', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '23-27', '', '39%', 'M3', '', ''),
  NamedMaterial('O1', 'Tool Steel and High Alloy Steel (Annealed)', 'P10, P13',
      '≤20', '93-100', '42%', 'O1', '100MnCrW4', ''),
  NamedMaterial('403', 'Ferritic Stainless Steel', 'P15', '', '82-90', '55%',
      '403', 'X7Cr13', ''),
  NamedMaterial('405', 'Ferritic Stainless Steel', 'P15', '', '82-90', '60%',
      '405', 'X10CrAl13', ''),
  NamedMaterial('410', 'Ferritic Stainless Steel', 'P15', '', '82-90', '55%',
      '410', 'X10Cr13', ''),
  NamedMaterial('416', 'Ferritic Stainless Steel', 'P15', '', '82-90', '90%',
      '41600', 'X12CrS13', ''),
  NamedMaterial('430', 'Ferritic Stainless Steel', 'P15', '', '82-90', '54%',
      '430', 'X8Cr17', ''),
  NamedMaterial('430F', 'Ferritic Stainless Steel', 'P15', '', '86-93', '65%',
      '430F', 'X12CrMoS17', ''),
  NamedMaterial('440A', 'Ferritic Stainless Steel', 'P15', '21-26', '≥100',
      '48%', '440A', 'X70CrMo15', ''),
  NamedMaterial('446', 'Ferritic Stainless Steel', 'P15', '', '86-93', '36%',
      '446', 'X10CrAl24', ''),
  NamedMaterial('Aermet 100', 'Ferritic Stainless Steel', 'P15', '43-45', '',
      '32%', 'AMS 6532', '', ''),
  NamedMaterial('420', 'Martensitic Stainless Steel', 'P15', '', '93-99', '45%',
      '420', 'X20Cr13', ''),
  NamedMaterial('420F', 'Martensitic Stainless Steel', 'P15', '≤21', '93-100',
      '55%', '420F', 'X30Cr13', ''),
  NamedMaterial('431', 'Martensitic Stainless Steel', 'P15', '21-29', '≥100',
      '48%', '431', 'X22CrNi17', ''),
  NamedMaterial('440C', 'Martensitic Stainless Steel', 'P15', '23-29', '',
      '35%', '440C', 'X105CrMo17', ''),
  NamedMaterial('301', 'Austenitic Stainless Steel', 'M1', '', '86-93', '52%',
      '301', 'X12CrNi17-7', ''),
  NamedMaterial('302', 'Austenitic Stainless Steel', 'M1', '', '80-91', '47%',
      '302', 'X12CrNi18-9', ''),
  NamedMaterial('303', 'Austenitic Stainless Steel', 'M1', '', '84-91', '72%',
      '303', 'X8CrNiS18-9', ''),
  NamedMaterial('304', 'Austenitic Stainless Steel', 'M1', '', '80-91', '43%',
      '304', 'X5CrNi18-9', ''),
  NamedMaterial('316', 'Austenitic Stainless Steel', 'M1', '', '80-91', '40%',
      '316', 'X5CrNiMo17-12-2', ''),
  NamedMaterial('317', 'Austenitic Stainless Steel', 'M1', '', '84-93', '38%',
      '317', 'X5CrNiMo17-13', ''),
  NamedMaterial('347', 'Austenitic Stainless Steel', 'M1', '', '84-93', '36%',
      '347', 'X10CrNiNb18-9', ''),
  NamedMaterial('Custom 465', 'Austenitic Stainless Steel', 'M1', '28-36', '',
      '30%', 'AMS 5936', '', ''),
  NamedMaterial('Duplex 1803 (F51)', 'Duplex Stainless Steel', 'M3', '21-29',
      '≥100', '28%', 'ASTM A182 Grade F51', '', ''),
  NamedMaterial('Duplex 2205 (F60 / F51)', 'Duplex Stainless Steel', 'M3',
      '21-29', '≥100', '28%', 'ASTM A182 Grade F60', 'X2CrNiMoN22-5-3', ''),
  NamedMaterial('Duplex 2760 (F55)', 'Duplex Stainless Steel', 'M3', '26-31',
      '', '16%', 'ASTM A182 Grade F55', 'X2CrNiMoCuWN25-7-4', ''),
  NamedMaterial('Hyper Duplex 2707 (A276)', 'Duplex Stainless Steel', 'M3',
      '28-32', '', '10%', 'A276', 'X2CrNiMoCoN28-8-5-1', ''),
  NamedMaterial('15-5PH', 'Precipitation Hardening St. St.', 'M2', '35-41', '',
      '47%', '15-May', 'X4CrNiCuNb16.4', ''),
  NamedMaterial('17-4PH', 'Precipitation Hardening St. St.', 'M2', '35-41', '',
      '43%', '630', 'X5CrNiCuNb16-4', ''),
  NamedMaterial('321', 'Precipitation Hardening St. St.', 'M2', '', '80-91',
      '36%', '321', 'X10CrNiTi18-9', ''),
  NamedMaterial('GG10', 'Grey Cast Iron (180 HB Max)', 'K1, K3, K7', '',
      '60-89', '170%', 'A48-20B', 'GG10', ''),
  NamedMaterial('GG20', 'Grey Cast Iron (180 HB Max)', 'K1, K3, K7', '',
      '80-93', '127%', 'A48-30B', 'GG20', ''),
  NamedMaterial('GG25', 'Grey Cast Iron (180-260 HB)', 'K4', '', '89-97',
      '112%', 'A48-35B', 'GG25', ''),
  NamedMaterial('GG30', 'Grey Cast Iron (180-260 HB)', 'K4', '≤21', '93-100',
      '104%', 'A48-45B', 'GG30', ''),
  NamedMaterial('GG35', 'Grey Cast Iron (180-260 HB)', 'K4', '≤23', '≥93',
      '100%', 'A48-50B', 'GG35', ''),
  NamedMaterial('GG40', 'Grey Cast Iron (180-260 HB)', 'K4', '≤25', '≥97',
      '90%', 'A48-55B', 'GG40', ''),
  NamedMaterial('GGG-40', 'Nodular cast iron (160 HB Max)', 'K2, K5', '',
      '74-84', '140%', '60-40-18', 'GGG-40', ''),
  NamedMaterial('GGG-50', 'Nodular cast iron (180-280 HB)', 'K6', '', '89-97',
      '100%', '', '', ''),
  NamedMaterial('GGG-60', 'Nodular cast iron (180-280 HB)', 'K6', '≤23', '≥93',
      '94%', '80-55-06', 'GGG-60', ''),
  NamedMaterial('GGG-70', 'Nodular cast iron (180-280 HB)', 'K6', '≤28', '≥99',
      '70%', '100-70-03', 'GGG-70', ''),
  NamedMaterial('GGG-80', 'Nodular cast iron (180-280 HB)', 'K6', '23-32', '',
      '63%', '120-90-02', 'GGG-80', ''),
  NamedMaterial('GTS-35-10', 'Malleable cast iron (180 HB Max)', 'K1, K3, K7',
      '', '74-89', '205%', '32510', 'GTS-35-10', ''),
  NamedMaterial('GTS-45-06', 'Malleable cast iron (180 HB Max)', 'K1, K3, K7',
      '', '80-93', '149%', '', 'GTS-45-06', ''),
  NamedMaterial('GTS-55-04', 'Malleable cast iron (180-270 HB)', 'K2, K5',
      '≤21', '89-100', '107%', '', '', ''),
  NamedMaterial('GTS-65-02', 'Malleable cast iron (180-270 HB)', 'K2, K5',
      '≤26', '≥95', '84%', '70003', 'GTS-65-02', ''),
  NamedMaterial('GTS-70-02', 'Malleable cast iron (180-270 HB)', 'K2, K5',
      '≤26', '≥99', '62%', 'A220-80002', 'GTS-70-02', ''),
  NamedMaterial('2011', 'Aluminum - Wrought - Hardened', 'N2', '', '56-70',
      '280%', '2011', 'AlCuBiPb', ''),
  NamedMaterial('2014', 'Aluminum - Wrought - Hardened', 'N2', '', '63-76',
      '200%', '2017', 'AlCuSiMn', ''),
  NamedMaterial('2017', 'Aluminum - Wrought - Hardened', 'N2', '', '56-72',
      '200%', '2017', 'AlCuMg1', ''),
  NamedMaterial('2024', 'Aluminum - Wrought - Hardened', 'N2', '', '66-78',
      '210%', '2024', 'AlCuMg2', ''),
  NamedMaterial('3003', 'Aluminum - Wrought - Hardened', 'N2', '', '', '260%',
      '3003', 'AlMnCu', ''),
  NamedMaterial('3004', 'Aluminum - Wrought - Hardened', 'N2', '', '≤41',
      '260%', '3004', 'AlMn1Mg1', ''),
  NamedMaterial('5052', 'Aluminum - Wrought - Hardened', 'N2', '', '≤41',
      '260%', '5052', 'AlMg2,5', ''),
  NamedMaterial('5056', 'Aluminum - Wrought - Hardened', 'N2', '', '≤63',
      '270%', '5056', 'AlMg5', ''),
  NamedMaterial('6061', 'Aluminum - Wrought - Hardened', 'N2', '', '≤56',
      '270%', '6061', 'AlMgSiCu', ''),
  NamedMaterial('6063', 'Aluminum - Wrought - Hardened', 'N2', '', '', '270%',
      '6063', 'AlMgSi0,5', ''),
  NamedMaterial('7075', 'Aluminum - Wrought - Hardened', 'N2', '', '76-84',
      '170%', '7075', 'AlZnMgCu1,5', ''),
  NamedMaterial('C36000', 'Copper Alloys', 'N7, N8, N9', '', '≤60', '170%',
      'C36000', 'CuZn36Pb3', ''),
  NamedMaterial('20CB-3', 'Iron (Fe) Based - Supper Alloys', 'S2', '≤26', '≥99',
      '45%', 'ASTM B463', '', ''),
  NamedMaterial('A-286', 'Iron (Fe) Based - Supper Alloys', 'S2', '23-31', '',
      '40%', 'ASTM 368', 'X5NiCrTi2515', ''),
  NamedMaterial('Discaloy 16', 'Iron (Fe) Based - Supper Alloys', 'S2', '21-29',
      '≥100', '40%', '5725', '', ''),
  NamedMaterial('Discaloy 24', 'Iron (Fe) Based - Supper Alloys', 'S2', '21-29',
      '≥100', '40%', 'ASTM A638', '', ''),
  NamedMaterial('Incoloy 800', 'Iron (Fe) Based - Supper Alloys', 'S1', '',
      '80-89', '50%', 'ASME SB409', 'X10NiCrAlTi3220', ''),
  NamedMaterial('Incoloy 801', 'Iron (Fe) Based - Supper Alloys', 'S2', '≤21',
      '93-100', '50%', '5552', 'G.X50CrNi3030', ''),
  NamedMaterial('Incoloy 802', 'Iron (Fe) Based - Supper Alloys', 'S1', '',
      '86-97', '50%', '', '', ''),
  NamedMaterial('Incoloy DS', 'Iron (Fe) Based - Supper Alloys', 'S1', '',
      '86-97', '50%', '', 'X12NiCrSi3616', ''),
  NamedMaterial('Marval 18', 'Iron (Fe) Based - Supper Alloys', 'S2', '31-36',
      '', '25%', '', '', ''),
  NamedMaterial('Udimet B-250', 'Iron (Fe) Based - Supper Alloys', 'S2',
      '31-36', '', '25%', '', '', ''),
  NamedMaterial('Udimet B-300', 'Iron (Fe) Based - Supper Alloys', 'S2',
      '31-36', '', '25%', '', '', ''),
  NamedMaterial('W-545', 'Iron (Fe) Based - Supper Alloys', 'S2', '31-36', '',
      '40%', 'AlSl:665', '', ''),
  NamedMaterial(
      'Hastelloy C-276',
      'Nickel (Ni) Based - Supper Alloys (20 HRC Max)',
      'S3',
      '',
      '91-99',
      '20%',
      '',
      'G-NiMo30',
      ''),
  NamedMaterial('Hastelloy X', 'Nickel (Ni) Based - Supper Alloys (20 HRC Max)',
      'S3', '≤21', '93-100', '18%', '5536', 'NiCr22FeMo', ''),
  NamedMaterial('Monel 400', 'Nickel (Ni) Based - Supper Alloys (20 HRC Max)',
      'S3', '', '66-80', '45%', '4544', 'NiCu30Fe', ''),
  NamedMaterial('Monel K500', 'Nickel (Ni) Based - Supper Alloys (20 HRC Max)',
      'S3', '23-33', '', '35%', '4676', 'NiCu30Al', ''),
  NamedMaterial('Monel R405', 'Nickel (Ni) Based - Supper Alloys (20 HRC Max)',
      'S3', '', '66-80', '45%', '4674', '', ''),
  NamedMaterial('Nimonic 75', 'Nickel (Ni) Based - Supper Alloys (20 HRC Max)',
      'S3', '', '89-97', '17%', '', 'NiCr20Ti', ''),
  NamedMaterial('Haynes 556', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '21-33', '≥100', '19%', '5768', 'X12CrCoNi2120', ''),
  NamedMaterial('Haynes 625', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '23-33', '', '17%', 'ASME SB443', 'NiCr22Mo9Nb', ''),
  NamedMaterial('Haynes X-750', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '26-39', '', '13%', '5542', '', ''),
  NamedMaterial('Incoloy 903', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '26-36', '', '11%', '', 'NiFe42K15Nb', ''),
  NamedMaterial('Incoloy 925', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '26-36', '', '15%', '', '', ''),
  NamedMaterial('Inconel 050', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '28-39', '', '13%', '', '', ''),
  NamedMaterial('Inconel 625', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '23-33', '', '17%', 'ASME SB443.4', 'NiCr22Mo9Nb', ''),
  NamedMaterial('Inconel 702', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '21-31', '≥100', '19%', '5550', '', ''),
  NamedMaterial('Inconel 706', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '26-39', '', '11%', 'AMS 5702', '', ''),
  NamedMaterial('Inconel 718', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-43', '', '10%', '5383', 'NiCr19Fe19NbMo', ''),
  NamedMaterial(
      'Inconel 718 DA',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '33-44',
      '',
      '9%',
      '',
      '',
      ''),
  NamedMaterial(
      'Inconel 718 OP',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '31-43',
      '',
      '12%',
      '',
      '',
      ''),
  NamedMaterial(
      'Inconel 718 Plus',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '32-43',
      '',
      '10%',
      '',
      '',
      ''),
  NamedMaterial('Inconel 720', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '37-44', '', '9%', '', '', ''),
  NamedMaterial('Inconel 722', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '26-36', '', '14%', '5541', 'NiCr16FeTi', ''),
  NamedMaterial('Inconel 725', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-39', '', '13%', '', '', ''),
  NamedMaterial('Inconel 783', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '26-36', '', '14%', '', '', ''),
  NamedMaterial(
      'Inconel MA754',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '26-36',
      '',
      '17%',
      '',
      '',
      ''),
  NamedMaterial(
      'Inconel X-750',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '26-39',
      '',
      '15%',
      '5542',
      'NiCr16FeTi',
      ''),
  NamedMaterial(
      'Inconel X-751',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '26-39',
      '',
      '14%',
      '',
      '',
      ''),
  NamedMaterial('M-252', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)', 'S4',
      '31-39', '', '5%', '5551', 'G-NiCr19Co', ''),
  NamedMaterial('MP35N', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)', 'S4',
      '28-41', '', '18%', '', '', ''),
  NamedMaterial(
      'Multimet N-155',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '23-33',
      '',
      '18%',
      '5768',
      '',
      ''),
  NamedMaterial(
      'Multimet N-156',
      'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4',
      '23-33',
      '',
      '19%',
      '',
      '',
      ''),
  NamedMaterial('Nimonic 105', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-41', '', '14%', '', 'NiCo20Cr15MoAlTi', ''),
  NamedMaterial('Nimonic 80A', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '28-36', '', '12%', '', 'NiCr20TiAl', ''),
  NamedMaterial('Nimonic 90', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '28-36', '', '10%', '', 'NiCr20Co18Ti', ''),
  NamedMaterial('Nimonic 901', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-39', '', '13%', '5660, 5661', 'NiCr15MoTi', ''),
  NamedMaterial('Nimonic C263', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '26-36', '', '18%', '', 'NiCr20CoMoTi', ''),
  NamedMaterial('Nimonic PK33', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-39', '', '12%', '', 'NiCr20Co16MoTi', ''),
  NamedMaterial('René 41', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '33-44', '', '15%', '5712, 5713', 'NiCr19Co11MoTi', ''),
  NamedMaterial('S 590', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)', 'S4',
      '26-36', '', '18%', '5533', 'X40CoCrNi2020', ''),
  NamedMaterial('Udimet 520', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-39', '', '11%', '', '', ''),
  NamedMaterial('Udimet 718', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-43', '', '10%', '5383', 'NiCr19Fe19NbMo', ''),
  NamedMaterial('Waspaloy®', 'Nickel (Ni) Based - Supper Alloys (21-42 HRC)',
      'S4', '31-41', '', '12%', '5544', 'NiCr20Co14MoTi', ''),
  NamedMaterial('Stellite 151', 'Cobalt (Co) Based - Supper Alloys', 'S4',
      '43-51', '', '6%', '', '', ''),
  NamedMaterial('Stellite 21', 'Cobalt (Co) Based - Supper Alloys', 'S4',
      '31-38', '', '17%', '', '', ''),
  NamedMaterial('Stellite 25 (L605)', 'Cobalt (Co) Based - Supper Alloys', 'S4',
      '26-33', '', '12%', '5759', 'CoCr20W15Ni', ''),
  NamedMaterial('Stellite 31 (X40)', 'Cobalt (Co) Based - Supper Alloys', 'S4',
      '35-43', '', '6%', 'ASTM A567', 'CoCr25NiW', ''),
  NamedMaterial('Stellite 6', 'Cobalt (Co) Based - Supper Alloys', 'S4',
      '41-47', '', '19%', '', '', ''),
  NamedMaterial('Ti-99.5 (Grade 1)', 'Pure Titanium', 'S6', '', '70-84', '46%',
      'Grade 1 B381F4', 'Ti-99.5', ''),
  NamedMaterial('Ti-99.6 (Grade 2)', 'Pure Titanium', 'S6', '', '78-89', '40%',
      'Grade 2 B381F3', 'Ti-99.6', ''),
  NamedMaterial('Ti-99.7 (Grade 3)', 'Pure Titanium', 'S6', '', '86-93', '35%',
      'Grade 3 B381F2', 'Ti-99.7', ''),
  NamedMaterial('Ti-99.8 (grade 4)', 'Pure Titanium', 'S6', '≤21', '93-100',
      '28%', 'Grade 4 B381F1', 'Ti-99.8', ''),
  NamedMaterial(
      'Ti-10.2.3', 'Titanium alloys', 'S7, S8', '33-41', '', '18%', '', '', ''),
  NamedMaterial('Ti-13V-11Cr-3Al', 'Titanium alloys', 'S7, S8', '31-38', '',
      '15%', '4917', 'TiV13Cr11Al3', ''),
  NamedMaterial(
      'Ti-15-333', 'Titanium alloys', 'S7, S8', '31-38', '', '20%', '', '', ''),
  NamedMaterial('Ti-15Mo (Alpha + Beta)', 'Titanium alloys', 'S7, S8', '31-38',
      '', '16%', '', '', ''),
  NamedMaterial('Ti-15Mo (Beta)', 'Titanium alloys', 'S7, S8', '23-31', '',
      '28%', '', '', ''),
  NamedMaterial('Ti-3Al-2.5V', 'Titanium alloys', 'S7, S8', '23-33', '', '28%',
      '4943, 4944', '', ''),
  NamedMaterial('Ti-3Al-8V-6Cr-4Mo-4Zr', 'Titanium alloys', 'S7, S8', '31-38',
      '', '20%', '', '', ''),
  NamedMaterial(
      'Ti-425', 'Titanium alloys', 'S7, S8', '28-36', '', '17%', '', '', ''),
  NamedMaterial('Ti-425 MIL', 'Titanium alloys', 'S7, S8', '28-36', '', '17%',
      '', '', ''),
  NamedMaterial('Ti-48Al-2Cr-2Nb', 'Titanium alloys', 'S7, S8', '31-38', '',
      '31%', '', '', ''),
  NamedMaterial('Ti-4Al-4Mo-2Sn-0.5Si', 'Titanium alloys', 'S7, S8', '33-41',
      '', '18%', '', 'TiAl4Mo4Sn2Si0.5', ''),
  NamedMaterial('Ti-5Al-2Sn-2Zr-4Cr-4Mo', 'Titanium alloys', 'S7, S8', '33-41',
      '', '16%', '4995', 'Ti5Al2Sn2Zr4Cr4Mo', ''),
  NamedMaterial('Ti-5Al-5Mo-5V-1Cr-1Fe', 'Titanium alloys', 'S7, S8', '35-42',
      '', '15%', '', '', ''),
  NamedMaterial('Ti-5Al-5V-5Mo-3Cr', 'Titanium alloys', 'S7, S8', '35-42', '',
      '15%', '', '', ''),
  NamedMaterial('Ti-6-2-4-6', 'Titanium alloys', 'S7, S8', '33-41', '', '17%',
      '4981', '', ''),
  NamedMaterial(
      'Ti-6-7', 'Titanium alloys', 'S7, S8', '31-38', '', '20%', '', '', ''),
  NamedMaterial('Ti-6Al-4V (Grade 5)', 'Titanium alloys', 'S7, S8', '31-38', '',
      '20%', '4906, 4920, 4928,', 'TiAl6V4', ''),
  NamedMaterial('Ti-6Al-4V ELI', 'Titanium alloys', 'S7, S8', '31-38', '',
      '20%', '4907, 4930, 4931', '', ''),
  NamedMaterial('Ti-6Al-4V MIL', 'Titanium alloys', 'S7, S8', '31-38', '',
      '17%', '4906, 4920, 4928,', 'TiAl6V4', ''),
  NamedMaterial('Ti-6Al-4Zr-2Mo-2Sn', 'Titanium alloys', 'S7, S8', '33-41', '',
      '24%', '', '', ''),
  NamedMaterial('Ti-6Al-4Zr-2Mo-2Sn-0.2Si', 'Titanium alloys', 'S7, S8',
      '33-41', '', '24%', '4919, 4975, 4976', 'TiAl6Zr4Mo2Sn2', ''),
  NamedMaterial('Ti-6Al-6V-2Sn', 'Titanium alloys', 'S7, S8', '33-41', '',
      '18%', '4971', 'TiAl16V6Sn2', ''),
  NamedMaterial('Ti-8Al-1Mo-1V', 'Titanium alloys', 'S7, S8', '31-38', '',
      '18%', '4915, 4933, 4972', 'TiAl8Mo1V1', ''),
];

// ------------------------------------------------------------
// YG-1 VDI 3323 MATERIAL GROUPS CROSS-REFERENCE
// Bulk-imported from YG-1's "Technical Information — Material
// Groups" chart (VDI 3323 groups 1-41 under ISO P/M/K/N/S/H
// families). That chart classifies by VDI group + HB/HRc only —
// it has no kc1.1/mc Kienzle constants of its own, so each VDI
// group here is mapped to the closest existing Walter kc1.1/mc
// bucket above by hardness/composition (approximate, not a
// verified match — see the walterGroup comment on each block).
// Standard-code columns beyond SAE/DIN/EN (JIS/BS/AFNOR/SS/UNS/
// GOST/Brand) are packed into `refs`, pipe-separated, since the
// source table has more columns than the app's schema — still
// fully searchable, just not shown as their own UI column.
// Added incrementally, group by group, to keep each batch
// checkable rather than transcribing all ~450 rows unchecked.
// ------------------------------------------------------------

// VDI Group 1 — Non-alloyed steel, ~0.15% C, Annealed, HB 125.
// Mapped to Walter group 'P1, P6' (non/low-alloyed steel, low-med
// strength, Rm 350-750) — the closest existing bucket for a soft
// annealed low-carbon steel.
const List<NamedMaterial> _kVdiGroup1 = [
  NamedMaterial(
      'St 37-2',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'St 37-2',
      '',
      'JIS STKM12C | BS 4360 40B | EN S235JR | AFNOR E24-2 | SS 1311 | UNI Fe 360 B | Brand 16D | Mat.No 1.0037'),
  NamedMaterial(
      'St 37-3',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A570.36',
      'St 37-3',
      '',
      'JIS STKM12A | BS 4360 40C | EN S275J2G3 | AFNOR E28-3 | SS 1312 | UNI Fe 360 D FF | Brand ST14KP | Mat.No 1.0038'),
  NamedMaterial(
      'S 355 JR',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S 355 JR',
      '',
      'JIS SM490YA | EN S 1207 | AFNOR E36-2 | UNI Fe 510 BFN | Mat.No 1.0045'),
  NamedMaterial(
      'St 50-2',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A570 Gr. 50',
      'St 50-2',
      '',
      'JIS SS50 | BS 4360 50B | EN E 295 | AFNOR A50-2 | SS 2172 | UNI Fe 490 | Brand ST5PS | Mat.No 1.0050'),
  NamedMaterial(
      'St 60-2',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A572 Gr. 65',
      'St 60-2',
      '',
      'JIS SM58 | BS 4360 55E | AFNOR A60-2 | SS 1650 | UNI Fe 60-2 | Brand ST6PS | Mat.No 1.0060'),
  NamedMaterial(
      'S 235 J0',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S 235 J0',
      '',
      'BS En 40C | EN S 235 J0 | AFNOR E24-3 | UNI Fe 360 CFN | Mat.No 1.0114'),
  NamedMaterial(
      'S 275 J0',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S 275 J0',
      '',
      'EN S 275 J0 | AFNOR E28-3 | SS 1414 | UNI Fe 430 C | Mat.No 1.0143'),
  NamedMaterial(
      'St 44-3 N',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A573 Gr. 81',
      'St 44-3 N',
      '',
      'JIS SM41C, SM400 | BS 4360 43C | EN S 275 J2 G3 | AFNOR E28-3 | SS 1412 | UNI Fe 430 D FF | Brand ST14KP | Mat.No 1.0144'),
  NamedMaterial(
      'Ro St 44-2',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'Ro St 44-2',
      '',
      'BS 43C | EN S 275 J0 H | SS 1412 | UNI Fe430C | Mat.No 1.0149'),
  NamedMaterial(
      'C10',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1010',
      'C10',
      '',
      'JIS S10C | BS 045M10 | AFNOR 34C10, XC10 | UNI C10 | UNE F.1511 | UNS G10100 | Brand 10 | Mat.No 1.0301'),
  NamedMaterial(
      'St 12',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'St 12',
      '',
      'JIS SPCC | BS DC01 | EN Fe P01 | AFNOR DC01/FeP01 | SS 1142 | UNI FeP01 | Brand 15KP | Mat.No 1.0330'),
  NamedMaterial(
      'DD13 (StW24)',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A622(1008)',
      'DD13 (StW24)',
      '',
      'JIS SPHE | BS HS3 | EN DD13 | AFNOR 3C | UNI FeP13 | Brand 08KP | Mat.No 1.0335'),
  NamedMaterial(
      'St4',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A620(1008)',
      'St4',
      '',
      'JIS SPCE | BS 14491CR | EN FeP04 | AFNOR Fe14 | SS 1147 | UNI DC04/FeP04 | Brand 08JU | Mat.No 1.0338'),
  NamedMaterial(
      'P235GH',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A516 Gr.65',
      'P235GH',
      'P235GH',
      'JIS SPV50 | AFNOR A37CP | SS 1330 | UNI FeE235 | UNS K02503 | Mat.No 1.0345'),
  NamedMaterial(
      'C15',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1015',
      'C15',
      '',
      'JIS S15C | BS 080M15 | AFNOR C18RR, XC18 | SS 1350 | UNI C15,C16 | UNE F.1110 | UNS G10170 | Brand 15 | Mat.No 1.0401'),
  NamedMaterial(
      'C22',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1020',
      'C22',
      '1C22',
      'JIS S20C | BS 050A20 | AFNOR C20 | SS 1450 | UNI C20 | UNE F.1120 | UNS G10200 | Brand 20 | Mat.No 1.0402'),
  NamedMaterial(
      'P265GH/Hll',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'P265GH/Hll',
      '',
      'JIS SPV315 | AFNOR A42CP | SS 1430 | UNI Fe4101KW | UNS K02801 | Brand 16K | Mat.No 1.0425'),
  NamedMaterial(
      'GS-45',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A2765-35',
      'GS-45',
      'A1',
      'JIS SC450 | AFNOR E23-45M | SS 1305 | Mat.No 1.0443'),
  NamedMaterial(
      'S355NH',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S355NH',
      '',
      'AFNOR TSE355-4 | SS 2134 | UNI Fe510B | Mat.No 1.0539'),
  NamedMaterial(
      'S355N',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S355N',
      '4360-50E',
      'AFNOR E355R | SS 2334 | UNI FeE355KG | Mat.No 1.0545'),
  NamedMaterial(
      'S355NL',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S355NL',
      '4360-50EE',
      'AFNOR E355FP | SS 2135 | UNI FeE355KT | Mat.No 1.0546'),
  NamedMaterial(
      'S355J0H',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S355J0H',
      '4360-50C',
      'AFNOR TSE355-3 | SS 2172 | UNI Fe510C | Mat.No 1.0547'),
  NamedMaterial(
      'S355NLH',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S355NLH',
      '',
      'SS 2135 | UNI Fe510D | Mat.No 1.0549'),
  NamedMaterial(
      'StS2-3U',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A14880-40',
      'StS2-3U',
      '',
      'JIS SM520M | BS 4360-50C | AFNOR 320-560M | SS 1606 | UNI Fe510C | Mat.No 1.0553'),
  NamedMaterial(
      'StE355',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A633 Gr.C',
      'StE355',
      'P355N',
      'JIS SM490A | AFNOR FeE355KGN | SS 2132 | UNI FeE355KG | UNS K12000 | Brand 15GF | Mat.No 1.0562'),
  NamedMaterial(
      'WStE355',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'WStE355',
      'P355NH',
      'AFNOR P355NH | SS 2106 | UNI FeE355KW | UNS K01600 | Mat.No 1.0565'),
  NamedMaterial(
      'TStE355',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'TStE355',
      'P355NL1',
      'JIS SLA37 | AFNOR P355NL1 | SS 2107 | UNI FeE355KT | Mat.No 1.0566'),
  NamedMaterial(
      'St52-3',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1',
      'St52-3',
      'S355JR',
      'JIS SM50YA | BS 4360-50C | AFNOR E36-3 | SS 2172 | UNI Fe510B | Brand 17G1S | Mat.No 1.0570'),
  NamedMaterial(
      '9SMn28',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1213',
      '9SMn28',
      '',
      'JIS SUM22 | BS 230M07 | AFNOR S250 | SS 1912 | UNI CFSMn28 | UNE F.2111 | UNS G12130 | Mat.No 1.0715'),
  NamedMaterial(
      '9SMnPb28',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '12L13',
      '9SMnPb28',
      '',
      'JIS SUM22L | AFNOR S250Pb | SS 1914 | UNI CF9SMnPb28 | UNE F.2112 | UNS G12134 | Mat.No 1.0718'),
  NamedMaterial(
      '10S20',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1108',
      '10S20',
      '',
      'AFNOR 10S20 | UNI 10S20 | UNE F.2121 | UNS G11080 | Mat.No 1.0721'),
  NamedMaterial(
      '10SPb20',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '11L08',
      '10SPb20',
      '',
      'AFNOR 10PbF2 | UNI CF10SPb20 | UNS G11084 | Mat.No 1.0722'),
  NamedMaterial(
      '9SMn36',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1215',
      '9SMn36',
      '',
      'JIS SUM25 | AFNOR S300 | UNI CF9Mn36 | UNE F.2113 | UNS G12150 | Mat.No 1.0736'),
  NamedMaterial(
      '9SMnPb36',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '12L14',
      '9SMnPb36',
      '',
      'AFNOR S300Pb | SS 1926 | UNI CF9SMnPb36 | UNE F.2114 | UNS G12144 | Mat.No 1.0737'),
  NamedMaterial(
      'S315MC',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S315MC',
      '',
      'BS 1501-40F30 | AFNOR E315D | Mat.No 1.0972'),
  NamedMaterial(
      'S355MC',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S355MC',
      '',
      'BS 1501-43F35 | AFNOR E355D | SS 2642 | UNI FeE355TM | Mat.No 1.0976'),
  NamedMaterial('S460MC', 'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6', '', '', '', '', 'S460MC', '', 'BS 1501-50F45 | Mat.No 1.0982'),
  NamedMaterial(
      'S500MC (1.0984)',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S500MC',
      '',
      'AFNOR E490D | SS 2662 | UNI FeE490TM | Mat.No 1.0984'),
  NamedMaterial(
      'S500MC (1.0986)',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'S500MC',
      '',
      'BS 1501-60F55 | AFNOR E560D | UNI FeE560TM | Mat.No 1.0986'),
  NamedMaterial(
      'Ck10',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1010',
      'Ck10',
      '',
      'JIS S10C | BS 040A10 | AFNOR XC10 | SS 1265 | UNI C10 | UNE F.1510 | UNS G10100 | Brand 10 | Mat.No 1.1121'),
  NamedMaterial(
      'Ck15',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1015',
      'Ck15',
      '32C',
      'JIS S15 | BS 040A15 | AFNOR XC15 | SS 1370 | UNI C15 | UNE F.1110 | UNS G10150 | Brand 15 | Mat.No 1.1141'),
  NamedMaterial(
      'C22E',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '1020',
      'C22E',
      '',
      'JIS S20C | BS 055M15 | AFNOR 2C22 | SS 1450 | UNI C20 | UNE F.1120 | UNS G10230 | Brand 20 | Mat.No 1.1151'),
  NamedMaterial(
      'StE380',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A572-60',
      'StE380',
      '',
      'JIS S25C | BS 436055E | SS 2145 | UNI FeE390KG | Mat.No 1.8900'),
  NamedMaterial(
      'St44-2 (1.8900)',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      'A36',
      'St44-2',
      '',
      'BS 436043A | AFNOR NFA35-501E28 | SS 1411 | Mat.No 1.8900'),
  NamedMaterial(
      'StE320-3Z',
      'Non-alloyed steel (VDI 1) - ~0.15% C, Annealed',
      'P1, P6',
      '',
      '',
      '',
      '',
      'StE320-3Z',
      '',
      'BS 1501160 | SS 1421 | Mat.No 1.8900'),
];

// All named-material sources combined — this is what the rest of
// the app searches/browses. Bulk-imported VDI groups are appended
// after the hand-curated core list.
final List<NamedMaterial> kNamedMaterials = [
  ..._kNamedMaterialsCore,
  ..._kVdiGroup1,
];

// ------------------------------------------------------------
// ISO TOLERANCE (HOLE & SHAFT FITS)
// Tolerance WIDTH (the IT grade) uses the standard closed-form
// ISO 286 formula, which is exact. Tolerance POSITION (which
// letter sits where relative to nominal size) uses the classic
// "preferred fits" reference table reproduced in most machine
// design textbooks; treated here as an approximate reference —
// see the caveat shown in the Tolerance screen.
// ------------------------------------------------------------
const List<double> kToleranceStepBounds = [
  3,
  6,
  10,
  18,
  30,
  50,
  80,
  120,
  180,
  250,
  315,
  400,
  500
];

const Map<int, double> kItGradeMultiplier = {
  5: 7,
  6: 10,
  7: 16,
  8: 25,
  9: 40,
  10: 64,
  11: 100,
  12: 160,
  13: 250,
  14: 400,
  15: 640,
  16: 1000,
};

// Shaft fundamental deviation per letter (micrometres), one
// value per step in kToleranceStepBounds. c/d/e/f/g are the
// UPPER deviation (clearance fits, negative); k/n/p/s/u are the
// LOWER deviation (transition/interference fits, positive).
const Map<String, List<double>> kShaftDeviation = {
  'c': [
    -60,
    -70,
    -80,
    -95,
    -110,
    -120,
    -130,
    -150,
    -180,
    -200,
    -210,
    -230,
    -240
  ],
  'd': [-20, -30, -40, -50, -65, -80, -100, -120, -145, -170, -190, -210, -230],
  'e': [-14, -20, -25, -32, -40, -50, -60, -72, -85, -100, -110, -125, -135],
  'f': [-6, -10, -13, -16, -20, -25, -30, -36, -43, -50, -56, -62, -68],
  'g': [-2, -4, -5, -6, -7, -9, -10, -12, -14, -15, -17, -18, -20],
  'k': [0, 1, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4, 5],
  'n': [4, 8, 10, 12, 15, 17, 20, 23, 27, 31, 34, 37, 40],
  'p': [6, 12, 15, 18, 22, 26, 32, 37, 43, 50, 56, 62, 68],
  's': [14, 19, 23, 28, 35, 43, 53, 64, 76, 90, 100, 108, 114],
  'u': [18, 23, 28, 33, 41, 48, 60, 74, 88, 106, 126, 146, 166],
};

const List<String> kShaftLetters = [
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'js',
  'k',
  'n',
  'p',
  's',
  'u'
];
const List<String> kHoleLetters = [
  'D',
  'E',
  'F',
  'G',
  'H',
  'JS',
  'K',
  'N',
  'P',
  'S'
];

int _toleranceStepIndex(double d) {
  for (int i = 0; i < kToleranceStepBounds.length; i++) {
    if (d <= kToleranceStepBounds[i]) return i;
  }
  return kToleranceStepBounds.length - 1;
}

double _toleranceRangeGeoMean(double d) {
  final lo = _toleranceStepIndex(d) == 0
      ? 1.0
      : kToleranceStepBounds[_toleranceStepIndex(d) - 1];
  final hi = kToleranceStepBounds[_toleranceStepIndex(d)];
  return math.sqrt(lo * hi);
}

// IT value in micrometres for a given nominal size and grade.
double itValueMicrons(double nominalMm, int grade) {
  final dGeo = _toleranceRangeGeoMean(nominalMm);
  final i = 0.45 * math.pow(dGeo, 1 / 3) + 0.001 * dGeo; // tolerance unit, μm
  final mult = kItGradeMultiplier[grade] ?? kItGradeMultiplier[7]!;
  return i * mult;
}

// Returns (upperDeviationMicrons, lowerDeviationMicrons) for a hole.
// D/E/F/G and K/N/P/S are derived from the shaft table by mirroring
// with a sign flip (the standard ISO 286 "Delta = 0" simplification,
// exact for grades up to IT8 — the grades these letters are normally
// paired with; it drifts slightly at higher grades).
(double, double) holeDeviation(double nominalMm, int grade, String letter) {
  final it = itValueMicrons(nominalMm, grade);
  if (letter == 'H') return (it, 0);
  if (letter == 'JS') return (it / 2, -it / 2);

  final mirror = letter.toLowerCase();
  final table = kShaftDeviation[mirror];
  if (table == null) return (it, 0);
  final idx = _toleranceStepIndex(nominalMm);
  final dev = table[idx];

  if (['d', 'e', 'f', 'g'].contains(mirror)) {
    // Shaft clearance letters store the upper deviation (negative);
    // the mirrored hole's lower deviation is the sign-flipped value.
    final ei = -dev;
    return (ei + it, ei);
  }
  // k, n, p, s: shaft stores the lower deviation (positive); the
  // mirrored hole's upper deviation is the sign-flipped value.
  final es = -dev;
  return (es, es - it);
}

// Returns (upperDeviationMicrons, lowerDeviationMicrons) for a shaft.
(double, double) shaftDeviation(double nominalMm, int grade, String letter) {
  final it = itValueMicrons(nominalMm, grade);
  if (letter == 'h') return (0, -it);
  if (letter == 'js') return (it / 2, -it / 2);
  final idx = _toleranceStepIndex(nominalMm);
  final table = kShaftDeviation[letter];
  if (table == null) return (0, -it);
  final dev = table[idx];
  if (['c', 'd', 'e', 'f', 'g'].contains(letter)) {
    return (dev, dev - it); // dev is upper
  }
  return (dev + it, dev); // dev is lower (k, n, p, s, u)
}

// ------------------------------------------------------------
// THREAD STANDARDS (for Tapping)
// Major diameter and pitch are the defining constants of each
// standard itself (not an empirical chart), so confidence here
// is high. Values are entered as inches*25.4 / 25.4/TPI so the
// underlying inch figure stays visible and auditable in the code.
// NPT is the one exception: it's a tapered thread, so its true
// tap drill size is conventionally read from a manufacturer
// chart rather than computed — this uses the same diameter-minus-
// pitch rule as the others, off NPT's standard nominal pipe OD,
// as a reasonable approximation. Flagged in the UI.
// ------------------------------------------------------------
class ThreadSize {
  final String label;
  final double diameterMm;
  final double pitchMm;
  // Published tap drill size (mm), where available from a verified
  // source chart, rather than the computed D-pitch approximation.
  // Null falls back to the formula in _recalculate().
  final double? publishedDrillMm;
  const ThreadSize(this.label, this.diameterMm, this.pitchMm,
      [this.publishedDrillMm]);

  // TPI is how these standards are actually specified — pitch in mm
  // is just the derived/stored form used internally for calculation.
  double get tpi => 25.4 / pitchMm;
}

const List<ThreadSize> kUNC = [
  ThreadSize('#1', 0.073 * 25.4, 25.4 / 64),
  ThreadSize('#2', 0.086 * 25.4, 25.4 / 56),
  ThreadSize('#3', 0.099 * 25.4, 25.4 / 48),
  ThreadSize('#4', 0.112 * 25.4, 25.4 / 40),
  ThreadSize('#5', 0.125 * 25.4, 25.4 / 40),
  ThreadSize('#6', 0.138 * 25.4, 25.4 / 32),
  ThreadSize('#8', 0.164 * 25.4, 25.4 / 32),
  ThreadSize('#10', 0.190 * 25.4, 25.4 / 24),
  ThreadSize('#12', 0.216 * 25.4, 25.4 / 24),
  ThreadSize('1/4', 0.250 * 25.4, 25.4 / 20),
  ThreadSize('5/16', 0.3125 * 25.4, 25.4 / 18),
  ThreadSize('3/8', 0.375 * 25.4, 25.4 / 16),
  ThreadSize('7/16', 0.4375 * 25.4, 25.4 / 14),
  ThreadSize('1/2', 0.500 * 25.4, 25.4 / 13),
  ThreadSize('9/16', 0.5625 * 25.4, 25.4 / 12),
  ThreadSize('5/8', 0.625 * 25.4, 25.4 / 11),
  ThreadSize('3/4', 0.750 * 25.4, 25.4 / 10),
  ThreadSize('7/8', 0.875 * 25.4, 25.4 / 9),
  ThreadSize('1', 1.000 * 25.4, 25.4 / 8),
  ThreadSize('1-1/8', 1.125 * 25.4, 25.4 / 7),
  ThreadSize('1-1/4', 1.250 * 25.4, 25.4 / 7),
  ThreadSize('1-3/8', 1.375 * 25.4, 25.4 / 6),
  ThreadSize('1-1/2', 1.500 * 25.4, 25.4 / 6),
  ThreadSize('1-3/4', 1.750 * 25.4, 25.4 / 5),
  ThreadSize('2', 2.000 * 25.4, 25.4 / 4.5),
];

const List<ThreadSize> kUNF = [
  ThreadSize('#0', 0.060 * 25.4, 25.4 / 80),
  ThreadSize('#1', 0.073 * 25.4, 25.4 / 72),
  ThreadSize('#2', 0.086 * 25.4, 25.4 / 64),
  ThreadSize('#3', 0.099 * 25.4, 25.4 / 56),
  ThreadSize('#4', 0.112 * 25.4, 25.4 / 48),
  ThreadSize('#5', 0.125 * 25.4, 25.4 / 44),
  ThreadSize('#6', 0.138 * 25.4, 25.4 / 40),
  ThreadSize('#8', 0.164 * 25.4, 25.4 / 36),
  ThreadSize('#10', 0.190 * 25.4, 25.4 / 32),
  ThreadSize('#12', 0.216 * 25.4, 25.4 / 28),
  ThreadSize('1/4', 0.250 * 25.4, 25.4 / 28),
  ThreadSize('5/16', 0.3125 * 25.4, 25.4 / 24),
  ThreadSize('3/8', 0.375 * 25.4, 25.4 / 24),
  ThreadSize('7/16', 0.4375 * 25.4, 25.4 / 20),
  ThreadSize('1/2', 0.500 * 25.4, 25.4 / 20),
  ThreadSize('9/16', 0.5625 * 25.4, 25.4 / 18),
  ThreadSize('5/8', 0.625 * 25.4, 25.4 / 18),
  ThreadSize('3/4', 0.750 * 25.4, 25.4 / 16),
  ThreadSize('7/8', 0.875 * 25.4, 25.4 / 14),
  ThreadSize('1', 1.000 * 25.4, 25.4 / 12),
  ThreadSize('1-1/8', 1.125 * 25.4, 25.4 / 12),
  ThreadSize('1-1/4', 1.250 * 25.4, 25.4 / 12),
  ThreadSize('1-3/8', 1.375 * 25.4, 25.4 / 12),
  ThreadSize('1-1/2', 1.500 * 25.4, 25.4 / 12),
];

// BSW (British Standard Whitworth) — full range with published tap
// drill sizes, verified row-by-row against pitch = 25.4/TPI.
const List<ThreadSize> kBSW = [
  ThreadSize('1/16', 1.587, 0.423, 1.15),
  ThreadSize('3/32', 2.381, 0.529, 1.90),
  ThreadSize('1/8', 3.175, 0.635, 2.50),
  ThreadSize('5/32', 3.969, 0.793, 3.20),
  ThreadSize('3/16', 4.762, 1.058, 3.70),
  ThreadSize('7/32', 5.556, 1.058, 4.50),
  ThreadSize('1/4', 6.350, 1.270, 5.10),
  ThreadSize('5/16', 7.938, 1.411, 6.50),
  ThreadSize('3/8', 9.525, 1.588, 7.90),
  ThreadSize('7/16', 11.113, 1.814, 9.20),
  ThreadSize('1/2', 12.700, 2.117, 10.40),
  ThreadSize('9/16', 14.290, 2.117, 11.89),
  ThreadSize('5/8', 15.876, 2.309, 13.40),
  ThreadSize('3/4', 19.051, 2.540, 16.25),
  ThreadSize('7/8', 22.226, 2.822, 19.25),
  ThreadSize('1', 25.400, 3.175, 22.00),
  ThreadSize('1-1/8', 28.576, 3.629, 24.50),
  ThreadSize('1-1/4', 31.751, 3.629, 27.25),
  ThreadSize('1-3/8', 34.926, 4.233, 30.25),
  ThreadSize('1-1/2', 38.100, 4.233, 33.50),
  ThreadSize('1-5/8', 41.277, 5.080, 35.50),
  ThreadSize('1-3/4', 44.452, 5.080, 38.50),
  ThreadSize('1-7/8', 47.627, 5.645, 41.25),
  ThreadSize('2', 50.802, 5.645, 44.50),
  ThreadSize('2-1/4', 57.152, 6.350, 50.00),
  ThreadSize('2-1/2', 63.502, 6.350, 56.00),
  ThreadSize('2-3/4', 69.853, 7.257, 61.50),
  ThreadSize('3', 76.203, 7.257, 68.00),
  ThreadSize('3-1/4', 82.553, 7.816, 73.75),
  ThreadSize('3-1/2', 88.903, 7.816, 80.00),
  ThreadSize('3-3/4', 95.254, 8.467, 85.50),
  ThreadSize('4', 101.604, 8.467, 92.00),
];

// BSF (British Standard Fine) — full range through 2-3/4in (the
// chart marks tap drill "n/a" beyond that, so those aren't included).
const List<ThreadSize> kBSF = [
  ThreadSize('3/16', 4.763, 0.794, 4.00),
  ThreadSize('7/32', 5.556, 0.907, 4.60),
  ThreadSize('1/4', 6.350, 0.977, 5.30),
  ThreadSize('9/32', 7.142, 0.977, 6.10),
  ThreadSize('5/16', 7.938, 1.156, 6.80),
  ThreadSize('3/8', 9.525, 1.270, 8.30),
  ThreadSize('7/16', 11.113, 1.411, 9.70),
  ThreadSize('1/2', 12.700, 1.588, 11.10),
  ThreadSize('9/16', 14.288, 1.588, 12.70),
  ThreadSize('5/8', 15.875, 1.814, 14.00),
  ThreadSize('11/16', 17.463, 1.814, 15.50),
  ThreadSize('3/4', 19.050, 2.117, 16.75),
  ThreadSize('13/16', 20.638, 2.117, 18.25),
  ThreadSize('7/8', 22.225, 2.309, 19.75),
  ThreadSize('1', 25.400, 2.540, 22.75),
  ThreadSize('1-1/8', 28.575, 2.822, 26.50),
  ThreadSize('1-1/4', 31.750, 2.822, 28.75),
  ThreadSize('1-3/8', 34.925, 3.175, 31.50),
  ThreadSize('1-1/2', 38.100, 3.175, 34.50),
  ThreadSize('1-5/8', 41.275, 3.175, 38.00),
  ThreadSize('1-3/4', 44.450, 3.629, 40.50),
  ThreadSize('2', 50.800, 3.629, 47.00),
  ThreadSize('2-1/4', 57.150, 4.234, 53.00),
  ThreadSize('2-1/2', 63.500, 4.234, 59.00),
  ThreadSize('2-3/4', 69.850, 4.234, 64.30),
];

// BSP (parallel pipe / G-thread), DIN ISO 228 — starts at G1/8
// per the reference chart (no G1/16 listed in that standard).
const List<ThreadSize> kBSP = [
  ThreadSize('1/8', 9.73, 0.907, 8.80),
  ThreadSize('1/4', 13.16, 1.337, 11.80),
  ThreadSize('3/8', 16.66, 1.337, 15.25),
  ThreadSize('1/2', 20.95, 1.814, 19.00),
  ThreadSize('5/8', 22.91, 1.814, 21.00),
  ThreadSize('3/4', 26.44, 1.814, 24.50),
  ThreadSize('7/8', 30.20, 1.814, 28.25),
  ThreadSize('1', 33.25, 2.309, 30.75),
  ThreadSize('1-1/8', 37.90, 2.309, 35.30),
  ThreadSize('1-1/4', 41.91, 2.309, 39.25),
  ThreadSize('1-3/8', 44.32, 2.309, 41.70),
  ThreadSize('1-1/2', 47.80, 2.309, 45.25),
  ThreadSize('1-3/4', 53.74, 2.309, 51.10),
  ThreadSize('2', 59.61, 2.309, 57.00),
  ThreadSize('2-1/4', 65.71, 2.309, 63.10),
  ThreadSize('2-1/2', 75.18, 2.309, 72.60),
  ThreadSize('2-3/4', 81.53, 2.309, 78.90),
  ThreadSize('3', 87.88, 2.309, 85.30),
  ThreadSize('3-1/4', 93.98, 2.309, 91.50),
  ThreadSize('3-1/2', 100.33, 2.309, 97.70),
  ThreadSize('3-3/4', 106.68, 2.309, 104.00),
  ThreadSize('4', 113.03, 2.309, 110.40),
];

// NPT (ANSI B1.20.1) — full range with published tap drill sizes.
// Still tapered, so this reflects the chart's own values rather
// than a computed approximation.
const List<ThreadSize> kNPT = [
  ThreadSize('1/16', 7.895, 0.941, 6.00),
  ThreadSize('1/8', 10.242, 0.941, 8.25),
  ThreadSize('1/4', 13.616, 1.411, 10.70),
  ThreadSize('3/8', 17.055, 1.411, 14.10),
  ThreadSize('1/2', 21.223, 1.814, 17.40),
  ThreadSize('3/4', 26.568, 1.814, 22.60),
  ThreadSize('1', 33.228, 2.209, 28.50),
  ThreadSize('1-1/4', 41.985, 2.209, 37.00),
  ThreadSize('1-1/2', 48.054, 2.209, 43.50),
  ThreadSize('2', 60.092, 2.209, 55.00),
  ThreadSize('2-1/2', 72.699, 3.175, 65.50),
  ThreadSize('3', 88.608, 3.175, 81.50),
  ThreadSize('3-1/2', 101.316, 3.175, 94.30),
  ThreadSize('4', 113.973, 3.175, 107.00),
  ThreadSize('5', 141.300, 3.175, 134.384),
  ThreadSize('6', 168.275, 3.175, 161.191),
  ThreadSize('8', 219.075, 3.175, 211.673),
  ThreadSize('10', 273.050, 3.175, 265.311),
  ThreadSize('12', 323.850, 3.175, 315.793),
];

const Map<String, List<ThreadSize>> kThreadStandards = {
  'BSW': kBSW,
  'BSF': kBSF,
  'BSP': kBSP,
  'UNC': kUNC,
  'UNF': kUNF,
  'NPT': kNPT,
};

const List<String> kImperialThreadStandardNames = [
  'BSW',
  'BSF',
  'BSP',
  'UNC',
  'UNF',
  'NPT'
];

enum Operation { turning, milling, drilling, tapping }

// Drilling and Milling ask which tool family is being used before
// opening the calculator — Solid Carbide vs Indexable — since the
// feed-rate formula differs between them (indexable tools compute
// feed off a number-of-inserts count, the same way milling does).
enum ToolType { solidCarbide, indexable }

enum Units { metric, imperial }

class OpMeta {
  final Operation operation;
  final String label;
  final String subtitle;
  final IconData iconData;
  const OpMeta(this.operation, this.label, this.subtitle, this.iconData);
}

const List<OpMeta> kOperations = [
  OpMeta(
      Operation.turning, 'Turning', 'Lathe speeds & feeds', Icons.threesixty),
  OpMeta(Operation.milling, 'Milling', 'Mill speeds & feeds',
      Icons.grid_view_outlined),
  OpMeta(Operation.drilling, 'Drilling', 'Hole-making speeds & feeds',
      Icons.arrow_downward),
  OpMeta(Operation.tapping, 'Tapping', 'Thread tapping speeds & feeds',
      Icons.build_circle_outlined),
];

// Home-screen photo template assets — a real machining photo plus a
// semi-transparent red icon overlay, one pair per operation, used by
// the home grid cards instead of the plain icon-on-white-panel style.
const Map<Operation, String> kOperationPhotos = {
  Operation.turning: 'Assets/turning.png',
  Operation.milling: 'Assets/milling.png',
  Operation.drilling: 'Assets/drilling.png',
  Operation.tapping: 'Assets/tapping.png',
};

// ============================================================
// APP SHELL
// ============================================================
class MachiningApp extends StatelessWidget {
  const MachiningApp({super.key});

  // Above this viewport width, the app renders inside a centered
  // phone-width frame instead of stretching full-bleed — this only
  // matters on desktop web browsers; phones never hit this width.
  static const double _wideScreenBreakpoint = 700;
  static const double _frameWidth = 430;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YG Machining Calculator',
      theme: ThemeData(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: _C.brand),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        final width = MediaQuery.of(context).size.width;
        if (width < _wideScreenBreakpoint || child == null) return child!;
        return Container(
          color:
              const Color(0xFFE8E4EE), // surrounding backdrop on wide screens
          child: Center(
            child: Container(
              width: _frameWidth,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _C.bg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: MediaQuery(
                // Re-anchor the inner app's notion of "screen size" to
                // the frame width, so every screen's LayoutBuilder/
                // Expanded sizing (already written for phone widths)
                // behaves exactly the same inside the frame.
                data: MediaQuery.of(context).copyWith(
                  size: Size(_frameWidth, MediaQuery.of(context).size.height),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      home: const HomeScreen(),
    );
  }
}

// ============================================================
// HOME SCREEN — building-photo header (fading into the page
// background) with the animated logo badge floating on top,
// red action banner, and grid of tool cards.
// ============================================================

// Plays an animated GIF through its frames exactly once, then holds
// on the final frame — rather than looping forever the way
// Image.asset does natively for an animated GIF. Used for the home
// screen's logo, which should only "play" the one time it first
// appears, not repeatedly for as long as it's on screen.
class _PlayOnceGif extends StatefulWidget {
  final String assetPath;
  final double height;
  const _PlayOnceGif({required this.assetPath, required this.height});

  @override
  State<_PlayOnceGif> createState() => _PlayOnceGifState();
}

class _PlayOnceGifState extends State<_PlayOnceGif> {
  List<ui.Image>? _frames;
  List<Duration>? _durations;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(widget.assetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frames = <ui.Image>[];
      final durations = <Duration>[];
      for (int i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        frames.add(frame.image);
        durations.add(frame.duration);
      }
      if (!mounted) return;
      setState(() {
        _frames = frames;
        _durations = durations;
      });
      _scheduleNext();
    } catch (_) {
      // If decoding fails for any reason, just leave _frames null —
      // build() below renders a blank placeholder rather than crash.
    }
  }

  void _scheduleNext() {
    final frames = _frames;
    final durations = _durations;
    if (frames == null || durations == null) return;
    if (_index >= frames.length - 1) return; // already on the last frame
    _timer = Timer(durations[_index], () {
      if (!mounted) return;
      setState(() => _index++);
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = _frames;
    if (frames == null || frames.isEmpty) {
      return SizedBox(height: widget.height);
    }
    return RawImage(
      image: frames[_index],
      height: widget.height,
      fit: BoxFit.contain,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ---- Header: building photo fading into the background,
            // with the logo badge floating on top ----
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: ShaderMask(
                      shaderCallback: (rect) {
                        return LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black,
                            Colors.black,
                            Colors.black.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.72, 1.0],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        'Assets/abc.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const _PlayOnceGif(
                    assetPath: 'Assets/logo_animated.gif',
                    height: 115,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ---- Promo banner: icon + title + tagline ----
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: _C.brand,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _C.brand.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.calculate_outlined,
                                color: _C.brand, size: 19),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'YG MACHINING CALCULATOR',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                RichText(
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  text: const TextSpan(
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10.5),
                                    children: [
                                      TextSpan(text: 'Calculate. '),
                                      TextSpan(
                                          text: 'Optimize. ',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w800)),
                                      TextSpan(text: 'Machine Better.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ---- 3x2 grid: 4 operations + Material + Tolerance —
                    // sized to the exact space available, so it never
                    // needs to scroll regardless of screen size.
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const crossAxisCount = 3;
                          const spacing = 10.0;
                          final items = <_HomeGridEntry>[
                            for (final op in kOperations)
                              _HomeGridEntry(
                                label: op.label,
                                iconData: op.iconData,
                                photoAsset: kOperationPhotos[op.operation],
                                onTap: () => _openOperation(context, op),
                              ),
                            _HomeGridEntry(
                              label: 'Material',
                              iconData: Icons.table_chart_outlined,
                              photoAsset: 'Assets/material.png',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const MaterialReferenceScreen()),
                              ),
                            ),
                            _HomeGridEntry(
                              label: 'Tolerance',
                              iconData: Icons.straighten,
                              photoAsset: 'Assets/tolerance.png',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ToleranceScreen()),
                              ),
                            ),
                          ];
                          const rows = 2;
                          final itemWidth = (constraints.maxWidth -
                                  spacing * (crossAxisCount - 1)) /
                              crossAxisCount;
                          final itemHeight =
                              (constraints.maxHeight - spacing * (rows - 1)) /
                                  rows;
                          return GridView.count(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: itemWidth / itemHeight,
                            physics: const NeverScrollableScrollPhysics(),
                            children: items
                                .map((e) => _HomeGridCard(entry: e))
                                .toList(),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SmallIconLink(
                          icon: Icons.info_outline,
                          label: 'About YG',
                          onTap: () => _openAboutYgWebsite(context),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 18,
                                  height: 18,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _C.brand.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Icon(Icons.verified_outlined,
                                      color: _C.brand, size: 11),
                                ),
                                const SizedBox(width: 6),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      const TextSpan(
                                        text: 'Since ',
                                        style: TextStyle(
                                          color: _C.textDark,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      WidgetSpan(
                                        alignment:
                                            PlaceholderAlignment.baseline,
                                        baseline: TextBaseline.alphabetic,
                                        child: TweenAnimationBuilder<int>(
                                          tween:
                                              IntTween(begin: 1900, end: 1981),
                                          duration: const Duration(
                                              milliseconds: 1400),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, value, child) =>
                                              Text(
                                            '$value',
                                            style: TextStyle(
                                              color: _C.brand,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Total Tooling solution provider',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _C.textMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        _SmallIconLink(
                          icon: Icons.headset_mic_outlined,
                          label: 'Support',
                          onTap: () => _showSupportDialog(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Drilling and Milling ask which tool family before opening the
// calculator, since the feed formula differs (see ToolType). Turning
// and Tapping don't have this choice and open straight through.
void _openOperation(BuildContext context, OpMeta op) {
  if (op.operation != Operation.drilling && op.operation != Operation.milling) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CalculatorDetailScreen(meta: op)),
    );
    return;
  }

  showDialog<ToolType>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('${op.label} — Tool Type',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Solid carbide and indexable tools use different feed-rate '
            'formulas. Choose which one you\'re using.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 20),
          _toolTypeButton(ctx, 'Solid Carbide', ToolType.solidCarbide),
          const SizedBox(height: 10),
          _toolTypeButton(ctx, 'Indexable', ToolType.indexable),
        ],
      ),
    ),
  ).then((toolType) {
    if (toolType == null || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalculatorDetailScreen(meta: op, toolType: toolType),
      ),
    );
  });
}

Widget _toolTypeButton(BuildContext ctx, String label, ToolType value) {
  return ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: _C.brand,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    onPressed: () => Navigator.pop(ctx, value),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

Future<void> _openAboutYgWebsite(BuildContext context) async {
  final uri = Uri.parse('https://brand.yg1.solutions/en/index.do');
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the YG-1 website.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the YG-1 website.')),
      );
    }
  }
}

void _showSupportDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title:
          const Text('Support', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _supportRow(Icons.language, 'www.yg1.solutions'),
          _supportRow(Icons.phone_outlined, '+91 80 2204 4620'),
          _supportRow(Icons.email_outlined, 'marketing.india@yg1.solutions'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Close', style: TextStyle(color: _C.brand)),
        ),
      ],
    ),
  );
}

Widget _supportRow(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _C.brand),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );
}

// Small circular-outline icon + label, used for low-emphasis utility
// links (About/Support) at the very bottom of the home screen.
class _SmallIconLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallIconLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _C.brand, width: 1.3),
              ),
              child: Icon(icon, color: _C.brand, size: 15),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                color: _C.textDark,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// One entry shown in the home grid — either a machining operation
// (image icon) or a reference tool (Material icon), all rendered
// through the same card so the grid stays visually consistent.
class _HomeGridEntry {
  final String label;
  final String? iconAsset;
  final IconData? iconData;
  // When set, the card uses the photo-template layout (photo with an
  // optional icon overlay on top, solid red label banner on the
  // bottom) instead of the plain icon-on-white-panel fallback.
  final String? photoAsset;
  final String? photoOverlayAsset;
  final VoidCallback onTap;
  const _HomeGridEntry({
    required this.label,
    this.iconAsset,
    this.iconData,
    this.photoAsset,
    this.photoOverlayAsset,
    required this.onTap,
  });
}

// A single home-grid card. Two layouts:
// - Photo template (when entry.photoAsset is set): a machining photo
//   fills the top area with the operation's red icon overlaid semi-
//   transparently on top, and a solid red banner with the label sits
//   along the bottom — matches the reference button template.
// - Plain fallback (used until an operation has its own photo): a
//   large icon centered over a tinted panel, with the label below.
// No CTA button in either case — the whole card is tappable, so a
// separate button just duplicated the action while eating space.
class _HomeGridCard extends StatelessWidget {
  final _HomeGridEntry entry;
  const _HomeGridCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = entry.photoAsset != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: entry.onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: hasPhoto
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: hasPhoto
            ? Column(
                children: [
                  Expanded(
                    child: Image.asset(entry.photoAsset!, fit: BoxFit.cover),
                  ),
                  Container(
                    width: double.infinity,
                    color: _C.brand,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entry.label.toUpperCase(),
                        maxLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: entry.iconAsset != null
                              ? Image.asset(entry.iconAsset!,
                                  fit: BoxFit.contain)
                              : Icon(entry.iconData,
                                  color: _C.brand,
                                  size: constraints.maxHeight * 0.32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          entry.label,
                          maxLines: 1,
                          style: const TextStyle(
                            color: _C.textDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

// ============================================================
// DETAIL SCREEN — one operation's calculator
// ============================================================
class CalculatorDetailScreen extends StatefulWidget {
  final OpMeta meta;
  // Only meaningful for Drilling and Milling — null for Turning/
  // Tapping, which don't have a tool-family choice.
  final ToolType? toolType;
  const CalculatorDetailScreen({super.key, required this.meta, this.toolType});

  @override
  State<CalculatorDetailScreen> createState() => _CalculatorDetailScreenState();
}

class _CalculatorDetailScreenState extends State<CalculatorDetailScreen> {
  Units _units = Units.metric;
  ToolType get _toolType => widget.toolType ?? ToolType.solidCarbide;
  bool get _isIndexable => _toolType == ToolType.indexable;

  final _diameterCtrl = TextEditingController();
  final _speedCtrl = TextEditingController(); // cutting speed Vc
  final _rpmCtrl = TextEditingController(); // spindle speed n
  final _feedCtrl =
      TextEditingController(); // feed per rev/tooth, or thread pitch for tapping
  final _feedRateCtrl = TextEditingController(); // feed rate mm/min or in/min
  // — an alternative way to enter feed for Turning/Milling/Drilling,
  // synced bidirectionally with _feedCtrl the same way Vc <-> RPM is.
  // Not used for Tapping, where feed is thread pitch, not a free choice.
  final _depthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _teethCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _toolPriceCtrl = TextEditingController(); // cost of one tool/insert
  final _edgesCtrl =
      TextEditingController(); // number of usable cutting edges/corners on that tool
  final _toolLifeCtrl =
      TextEditingController(); // AVERAGE components produced per edge —
  // real edges don't wear identically, so this is an estimate,
  // the same way any tooling-cost model works in practice.
  final _holesCtrl =
      TextEditingController(); // number of holes — Drilling & Tapping only
  final _passesCtrl =
      TextEditingController(); // number of passes — Turning & Milling only

  double? _rpm;
  double? _feedRate;
  double? _mrr;
  double? _time;
  double? _drillSize; // tapping only
  double? _kc; // specific cutting force, N/mm^2
  double? _cuttingForce; // Fc, N
  double? _torque; // Nm
  double? _power; // kW
  double? _cpc; // Cost Per Component = tool price / components per tool life
  double? _totalTime; // Cycle time × number of holes — Drilling & Tapping
  MaterialSpec? _material;
  // When a specific alloy is picked via search (e.g. "4140"), this
  // holds its name for display; the underlying kc1.1/mc still comes
  // from _material, resolved via that alloy's Walter group.
  String? _materialDisplayName;
  // Whether the material-force stats (kc, Fc, torque, power) are shown
  // under the primary results in the gradient panel, or collapsed.
  bool _resultsExpanded = true;

  // Tapping only: which thread standard is driving diameter/pitch.
  // 'Metric' means the user types diameter+pitch manually (default,
  // original behaviour). Any other value means a size was picked
  // from that standard's table, which fills diameter/pitch for you.
  String _threadStandard = 'BSW';
  ThreadSize? _selectedThreadSize;

  // Tapping only: Cut taps remove material (~75% thread engagement,
  // the D-P rule already used). Form/roll taps displace material
  // upward into the crest instead of cutting it, so they need a
  // noticeably larger pre-drill hole for the same nominal size —
  // conventionally sized to a looser ~65% engagement.
  bool _isFormTap = false;
  static const double kCutTapFactor = 1.0;
  static const double kFormTapFactor = 0.65;

  // Whichever of Vc / RPM the user typed into most recently is the
  // "driving" value; the other field is kept in sync automatically.
  bool _rpmIsDriving = false;
  // Same idea for Feed [f] vs Feed rate [Vf] (Turning/Milling/Drilling
  // only) — whichever the user is entering drives the other.
  bool _feedRateIsDriving = false;
  // Guards against a programmatic text update re-triggering its own
  // listener and causing an infinite loop.
  bool _syncing = false;
  // Hard reentrancy guard on _recalculate itself — belt-and-braces on
  // top of _syncing, so no code path (present or future) can ever
  // cause a recursive/looping recalculation.
  bool _recalculating = false;
  // Real focus state for the two fields — used as the primary signal
  // for which one is "driving", since it can't be fooled by a stray
  // or missed listener callback the way a plain flag can.
  final FocusNode _speedFocusNode = FocusNode();
  final FocusNode _rpmFocusNode = FocusNode();
  final FocusNode _feedFocusNode = FocusNode();
  final FocusNode _feedRateFocusNode = FocusNode();

  // Fixed assumptions used in the force/power model, since we
  // don't add extra fields for these: 90 degree entry angle
  // (turning), and 80% overall machine efficiency.
  static const double _assumedEfficiency = 0.80;

  Operation get _operation => widget.meta.operation;
  Color get _accent => _C.brand;

  @override
  void initState() {
    super.initState();
    // Every field recalculates live as the user types — no
    // "Calculate" button. The two speed fields also need to track
    // which one is currently driving the spindle-speed relationship.
    _diameterCtrl.addListener(_recalculate);
    _speedCtrl.addListener(() {
      if (_syncing) return;
      _rpmIsDriving = false;
      _recalculate();
    });
    _rpmCtrl.addListener(() {
      if (_syncing) return;
      _rpmIsDriving = true;
      _recalculate();
    });
    // Also update the driving flag the moment focus lands on a field
    // (before any keystroke), so tapping into RPM immediately makes
    // it the driving field rather than waiting for the first digit —
    // and so the flag stays correct as the fallback for whenever
    // neither field currently has focus.
    _speedFocusNode.addListener(() {
      if (_speedFocusNode.hasFocus) {
        _rpmIsDriving = false;
        setState(() {});
      }
    });
    _rpmFocusNode.addListener(() {
      if (_rpmFocusNode.hasFocus) {
        _rpmIsDriving = true;
        setState(() {});
      }
    });
    _feedCtrl.addListener(() {
      if (_syncing) return;
      _feedRateIsDriving = false;
      _recalculate();
    });
    _feedRateCtrl.addListener(() {
      if (_syncing) return;
      _feedRateIsDriving = true;
      _recalculate();
    });
    _feedFocusNode.addListener(() {
      if (_feedFocusNode.hasFocus) {
        _feedRateIsDriving = false;
        setState(() {});
      }
    });
    _feedRateFocusNode.addListener(() {
      if (_feedRateFocusNode.hasFocus) {
        _feedRateIsDriving = true;
        setState(() {});
      }
    });
    _depthCtrl.addListener(_recalculate);
    _widthCtrl.addListener(_recalculate);
    _teethCtrl.addListener(_recalculate);
    _lengthCtrl.addListener(_recalculate);
    _toolPriceCtrl.addListener(_recalculate);
    _toolLifeCtrl.addListener(_recalculate);
    _edgesCtrl.addListener(_recalculate);
    _holesCtrl.addListener(_recalculate);
    _passesCtrl.addListener(_recalculate);
  }

  @override
  void dispose() {
    _diameterCtrl.dispose();
    _speedCtrl.dispose();
    _rpmCtrl.dispose();
    _feedCtrl.dispose();
    _feedRateCtrl.dispose();
    _depthCtrl.dispose();
    _widthCtrl.dispose();
    _teethCtrl.dispose();
    _lengthCtrl.dispose();
    _toolPriceCtrl.dispose();
    _toolLifeCtrl.dispose();
    _edgesCtrl.dispose();
    _holesCtrl.dispose();
    _passesCtrl.dispose();
    _speedFocusNode.dispose();
    _rpmFocusNode.dispose();
    _feedFocusNode.dispose();
    _feedRateFocusNode.dispose();
    super.dispose();
  }

  String get uDiameter => _units == Units.metric ? 'mm' : 'in';
  String get uSpeed => _units == Units.metric ? 'm/min' : 'SFM';
  String get uFeedRev => _units == Units.metric ? 'mm/rev' : 'in/rev';
  String get uFeedTooth => _units == Units.metric ? 'mm/tooth' : 'in/tooth';
  String get uPitch => _units == Units.metric ? 'mm/rev' : 'in/rev';
  String get uDepth => _units == Units.metric ? 'mm' : 'in';
  String get uFeedRate => _units == Units.metric ? 'mm/min' : 'in/min';
  String get uMrr => _units == Units.metric ? 'cm3/min' : 'in3/min';
  String get uLength => _units == Units.metric ? 'mm' : 'in';

  // Sets a controller's text without letting its own listener fire.
  void _setSilently(TextEditingController ctrl, String text) {
    _syncing = true;
    ctrl.text = text;
    _syncing = false;
  }

  // ============================================================
  // MATH
  // Runs on every keystroke. Computes whatever it can from
  // whatever fields are currently filled in — no button, no
  // all-or-nothing validation. Missing/invalid fields just mean
  // their downstream results stay blank until filled in.
  // ============================================================
  void _recalculate() {
    if (_recalculating) return;
    _recalculating = true;
    try {
      _recalculateImpl();
    } finally {
      _recalculating = false;
    }
  }

  void _recalculateImpl() {
    final D = double.tryParse(_diameterCtrl.text);
    double? Vc = double.tryParse(_speedCtrl.text);
    double? n = double.tryParse(_rpmCtrl.text);
    double? f = double.tryParse(_feedCtrl.text);
    double? feedRateVal = double.tryParse(_feedRateCtrl.text);
    final ap = double.tryParse(_depthCtrl.text);
    final ae = double.tryParse(_widthCtrl.text);
    final z = double.tryParse(_teethCtrl.text);
    final L = double.tryParse(_lengthCtrl.text);

    // Resolve the Vc <-> RPM relationship, keeping the non-driving
    // field's on-screen text in sync with whichever one is driving.
    // Live focus is the primary signal — it can't be fooled by a
    // stray/missed listener callback the way a plain flag alone can.
    // When neither field currently has focus (e.g. right after a
    // units toggle, or before the user has touched either field yet)
    // fall back to whichever one drove last.
    final rpmDriving = _rpmFocusNode.hasFocus
        ? true
        : _speedFocusNode.hasFocus
            ? false
            : _rpmIsDriving;
    if (D != null && D > 0) {
      if (!rpmDriving && Vc != null && Vc > 0) {
        n = _units == Units.metric
            ? (Vc * 1000) / (math.pi * D)
            : (Vc * 12) / (math.pi * D);
        if (n.isFinite) _setSilently(_rpmCtrl, n.toStringAsFixed(0));
      } else if (rpmDriving && n != null && n > 0) {
        Vc = _units == Units.metric
            ? (n * math.pi * D) / 1000
            : (n * math.pi * D) / 12;
        if (Vc.isFinite) _setSilently(_speedCtrl, Vc.toStringAsFixed(2));
      }
    }

    // Resolve the Feed [f] <-> Feed rate [Vf] relationship, the same
    // way, for Turning/Milling/Drilling. Tapping's "feed" is thread
    // pitch — a fixed property of the thread, not a free second
    // input — so it's excluded here and keeps its original one-way
    // behaviour (Vf follows from pitch × RPM only).
    if (_operation != Operation.tapping && n != null && n > 0) {
      // Indexable milling/drilling compute feed off an insert count,
      // like Vf = fz × Z × n; turning and solid-carbide drilling use
      // the simpler Vf = f × n.
      double? multiplier;
      if (_operation == Operation.milling ||
          (_operation == Operation.drilling && _isIndexable)) {
        if (z != null && z > 0) multiplier = z * n;
      } else {
        multiplier = n;
      }

      if (multiplier != null && multiplier > 0) {
        final feedRateDriving = _feedRateFocusNode.hasFocus
            ? true
            : _feedFocusNode.hasFocus
                ? false
                : _feedRateIsDriving;
        if (!feedRateDriving && f != null && f > 0) {
          feedRateVal = f * multiplier;
          if (feedRateVal.isFinite) {
            _setSilently(_feedRateCtrl, feedRateVal.toStringAsFixed(2));
          }
        } else if (feedRateDriving && feedRateVal != null && feedRateVal > 0) {
          f = feedRateVal / multiplier;
          if (f.isFinite) _setSilently(_feedCtrl, f.toStringAsFixed(4));
        }
      }
    }

    final toolPrice = double.tryParse(_toolPriceCtrl.text);
    final toolLifePerEdge = double.tryParse(_toolLifeCtrl.text);
    final edgesEntered = double.tryParse(_edgesCtrl.text);
    // Blank/invalid defaults to 1 edge, so solid tools (which don't
    // have a multi-edge concept) work the same as before this field
    // was added — only indexable inserts typically need > 1 here.
    final edges =
        (edgesEntered != null && edgesEntered > 0) ? edgesEntered : 1.0;

    setState(() {
      _rpm = null;
      _feedRate = null;
      _mrr = null;
      _time = null;
      _drillSize = null;
      _kc = null;
      _cuttingForce = null;
      _torque = null;
      _power = null;
      _totalTime = null;
      // CPC only applies to Turning and Indexable Milling — those are
      // the two cases where an insert's per-edge economics actually
      // matter here. It's computed independently of the cutting-
      // parameter guards below, so it still shows up even before
      // D/Vc/f are entered.
      // CPC = Tool Price / (Cutting Edges × Avg. Life per Edge) —
      // the total components one tool produces across every edge it
      // has, not just one edge's worth.
      final cpcApplies = _operation == Operation.turning ||
          (_operation == Operation.milling && _isIndexable);
      _cpc = (cpcApplies &&
              toolPrice != null &&
              toolPrice > 0 &&
              toolLifePerEdge != null &&
              toolLifePerEdge > 0)
          ? toolPrice / (edges * toolLifePerEdge)
          : null;

      if (D == null || D <= 0 || Vc == null || Vc <= 0 || n == null || n <= 0) {
        return; // not enough info yet — leave results blank
      }
      _rpm = n;

      if (f == null || f <= 0) return; // feed still needed for everything else

      switch (_operation) {
        case Operation.turning:
          final vf = f * n;
          _feedRate = vf;
          _time = (L != null && L > 0) ? L / vf : null;
          if (ap != null && ap > 0) {
            _mrr = _units == Units.metric ? Vc! * ap * f : 12 * Vc! * f * ap;
          }
          break;

        case Operation.drilling:
          // Indexable drills (e.g. spade/U-drills) compute feed off a
          // number-of-inserts count, the same way milling does — the
          // "feed" field becomes feed-per-insert rather than
          // feed-per-revolution. Solid carbide (twist) drills keep
          // the simple per-revolution formula.
          if (_isIndexable) {
            if (z == null || z <= 0) return; // insert count required
            final vf = f * z * n;
            _feedRate = vf;
            _time = (L != null && L > 0) ? L / vf : null;
            _mrr = _units == Units.metric
                ? (math.pi * D * D * vf) / 4000
                : (math.pi * D * D * vf) / 4;
          } else {
            final vf = f * n;
            _feedRate = vf;
            _time = (L != null && L > 0) ? L / vf : null;
            _mrr = _units == Units.metric
                ? (math.pi * D * D * vf) / 4000
                : (math.pi * D * D * vf) / 4;
          }
          break;

        case Operation.milling:
          if (z == null || z <= 0) return; // teeth count required for milling
          final vf = f * z * n;
          _feedRate = vf;
          _time = (L != null && L > 0) ? L / vf : null;
          if (ap != null && ap > 0 && ae != null && ae > 0) {
            _mrr =
                _units == Units.metric ? (ap * ae * vf) / 1000 : ap * ae * vf;
          }
          break;

        case Operation.tapping:
          final vf = f * n;
          _feedRate = vf;
          // Cycle time = tap-in + retract. A rigid tap has to reverse the
          // spindle and back out of the hole at the same feed rate it went
          // in at, so the honest cycle time is double the forward-only
          // pass, not just the time to reach depth.
          _time = (L != null && L > 0) ? (2 * L / vf) : null;
          // If a standard size with a verified published drill size is
          // selected and this is a Cut Tap, use that chart value directly
          // — it's more accurate than the D-pitch approximation, especially
          // for tapered threads like NPT. Form taps always use the formula,
          // since these charts are for cut taps.
          final published = (!_isFormTap && _units == Units.imperial)
              ? _selectedThreadSize?.publishedDrillMm
              : null;
          if (published != null) {
            _drillSize = published;
          } else {
            // Cut tap: drill = D - (1.0 x pitch), roughly 75% thread
            // engagement — the widely used rule of thumb. Form/roll
            // tap: drill = D - (0.65 x pitch), a larger hole since
            // material is displaced upward rather than cut away.
            // Always reported in mm, regardless of the unit toggle.
            final factor = _isFormTap ? kFormTapFactor : kCutTapFactor;
            _drillSize = _units == Units.metric
                ? (D - factor * f)
                : (D - factor * f) * 25.4;
          }
          break;
      }

      // Total cycle time across a batch — Drilling/Tapping use "No.
      // of Holes", Turning/Milling use "No. of Passes". _time above
      // always stays the per-unit (per-hole or per-pass) figure;
      // this is that × count.
      if (_time != null) {
        double? count;
        if (_operation == Operation.drilling ||
            _operation == Operation.tapping) {
          count = double.tryParse(_holesCtrl.text);
        } else if (_operation == Operation.turning ||
            _operation == Operation.milling) {
          count = double.tryParse(_passesCtrl.text);
        }
        _totalTime = (count != null && count > 0) ? _time! * count : null;
      }

      // ----------------------------------------------------------
      // MATERIAL-SPECIFIC FORCE / TORQUE / POWER
      // Uses the Kienzle specific-cutting-force model: kc =
      // kc1.1 / h^mc. Chip thickness h and chip area A depend on
      // the operation's geometry, so each gets its own (standard,
      // simplified) approximation. Not offered for tapping, since
      // a tap's cutting mechanics don't fit this chip-thickness
      // model. All internal geometry is normalized to millimetres
      // regardless of the Metric/Imperial toggle, since kc1.1 is
      // inherently defined in N/mm^2; results are reported in N,
      // Nm and kW regardless of the unit toggle.
      if (_material != null && _operation != Operation.tapping) {
        double mm(double v) => _units == Units.metric ? v : v * 25.4;
        double mPerMin(double v) => _units == Units.metric ? v : v * 0.3048;

        final Dmm = mm(D);
        final fmm = mm(f);
        final apmm = ap != null ? mm(ap) : null;
        final aemm = ae != null ? mm(ae) : null;
        final vcMmin = mPerMin(Vc!);

        double? h;
        double? A;
        double? qMetric;

        switch (_operation) {
          case Operation.turning:
            if (apmm != null) {
              h = fmm;
              A = apmm * fmm;
              qMetric = vcMmin * apmm * fmm;
            }
            break;
          case Operation.drilling:
            if (_isIndexable) {
              if (z != null && z > 0) {
                h = fmm;
                A = (Dmm / 2) * fmm;
                final vfMm = fmm * z * n;
                qMetric = (math.pi * Dmm * Dmm * vfMm) / 4000;
              }
            } else {
              h = fmm / 2;
              A = (Dmm / 2) * fmm;
              final vfMm = fmm * n;
              qMetric = (math.pi * Dmm * Dmm * vfMm) / 4000;
            }
            break;
          case Operation.milling:
            if (apmm != null && aemm != null) {
              h = fmm;
              A = apmm * fmm;
              final vfMm = fmm * z! * n;
              qMetric = (apmm * aemm * vfMm) / 1000;
            }
            break;
          case Operation.tapping:
            break;
        }

        if (h != null && h > 0 && A != null && qMetric != null) {
          final kc = _material!.kc11 / math.pow(h, _material!.mc);
          _kc = kc;
          _cuttingForce = A * kc;
          _torque = _cuttingForce! * (Dmm / 2) / 1000;
          _power = (qMetric * kc) / (60000 * _assumedEfficiency);
        }
      }
    });
  }

  void _clear() {
    _diameterCtrl.clear();
    _speedCtrl.clear();
    _rpmCtrl.clear();
    _feedCtrl.clear();
    _feedRateCtrl.clear();
    _depthCtrl.clear();
    _widthCtrl.clear();
    _teethCtrl.clear();
    _lengthCtrl.clear();
    _toolPriceCtrl.clear();
    _toolLifeCtrl.clear();
    _edgesCtrl.clear();
    _holesCtrl.clear();
    _passesCtrl.clear();
    _rpmIsDriving = false;
    _feedRateIsDriving = false;
    setState(() {
      _rpm = null;
      _feedRate = null;
      _mrr = null;
      _time = null;
      _drillSize = null;
      _kc = null;
      _cuttingForce = null;
      _torque = null;
      _power = null;
      _cpc = null;
      _totalTime = null;
    });
  }

  // Builds a one-page PDF summary of the currently entered parameters
  // and computed results, then opens the native share/print sheet so
  // it can be saved, emailed, or printed.
  // Helvetica (the default PDF font) has no Unicode support, so any
  // special character here (em-dash, superscript, ®, etc.) would
  // throw at render time. Swap the common ones for ASCII equivalents
  // and strip anything else that slips through.
  String _pdfSafe(String s) {
    return s
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('²', '2')
        .replaceAll('³', '3')
        .replaceAll('°', ' deg')
        .replaceAll('≤', '<=')
        .replaceAll('≥', '>=')
        .replaceAll('®', '')
        .replaceAll('µ', 'u')
        .replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  // A simple hand-built bar chart for the PDF: each bar's height is
  // scaled to that stat's own value relative to the largest value in
  // the set, with the exact figure and unit labeled on/under the bar
  // so it stays legible even though the metrics use different units.
  pw.Widget _pdfBarChart(List<(String, double, String)> stats, PdfColor brand) {
    if (stats.isEmpty) return pw.SizedBox();
    const maxBarHeight = 90.0;
    final maxVal = stats.map((s) => s.$2).reduce((a, b) => a > b ? a : b);

    final bars = <pw.Widget>[];
    for (var i = 0; i < stats.length; i++) {
      final (label, value, unit) = stats[i];
      final barHeight = maxVal > 0 ? (value / maxVal) * maxBarHeight + 2 : 2.0;
      if (i > 0) bars.add(pw.SizedBox(width: 10));
      bars.add(
        pw.Expanded(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(value.toStringAsFixed(2),
                  style: pw.TextStyle(
                      fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Container(
                height: barHeight,
                decoration: pw.BoxDecoration(
                  color: brand,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(3),
                    topRight: pw.Radius.circular(3),
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(_pdfSafe(label),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7)),
              pw.Text(_pdfSafe(unit),
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: bars,
      ),
    );
  }

  Future<void> _exportPdf() async {
    // Helvetica (dart_pdf's default base font) has no Unicode table,
    // which is what triggers the "no Unicode support" console
    // warnings. Loading a real Unicode font up front and setting it
    // as the document theme fixes that properly instead of just
    // avoiding certain characters.
    pw.Font? baseFont;
    pw.Font? boldFont;
    try {
      baseFont = await PdfGoogleFonts.robotoRegular();
      boldFont = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      baseFont = null;
      boldFont = null;
    }

    final doc = pw.Document(
      theme: (baseFont != null && boldFont != null)
          ? pw.ThemeData.withFont(base: baseFont, bold: boldFont)
          : null,
    );
    final brand = PdfColor.fromInt(0xFFED1C29);

    // Load the YG-1 logo to use as a faint diagonal watermark behind
    // the report content. If the asset can't be decoded for any
    // reason, fall back to no watermark rather than failing export.
    pw.MemoryImage? watermark;
    try {
      final logoData = await rootBundle.load('Assets/logo_animated.gif');
      watermark = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      watermark = null;
    }

    final paramRows = <List<String>>[];
    void addParam(String label, TextEditingController ctrl, String unit) {
      final v = ctrl.text.trim();
      if (v.isEmpty) return;
      paramRows.add([_pdfSafe(label), _pdfSafe(unit.isEmpty ? v : '$v $unit')]);
    }

    switch (_operation) {
      case Operation.turning:
        addParam('Diameter (D)', _diameterCtrl, uDiameter);
        addParam('Cutting speed (Vc)', _speedCtrl, uSpeed);
        addParam('Spindle speed (n)', _rpmCtrl, 'RPM');
        addParam('Feed (f)', _feedCtrl, uFeedRev);
        addParam('Feed rate (Vf)', _feedRateCtrl, uFeedRate);
        addParam('Depth of cut (ap)', _depthCtrl, uDepth);
        addParam('Cut length', _lengthCtrl, uLength);
        addParam('No. of Passes', _passesCtrl, 'passes');
        addParam('Tool Price', _toolPriceCtrl, '');
        addParam('Avg. Life/Edge (N)', _toolLifeCtrl, 'pcs');
        addParam('Cutting Edges (Ce)', _edgesCtrl, 'edges');
        break;
      case Operation.drilling:
        addParam('Drill diameter (D)', _diameterCtrl, uDiameter);
        addParam('Cutting speed (Vc)', _speedCtrl, uSpeed);
        addParam('Spindle speed (n)', _rpmCtrl, 'RPM');
        if (_isIndexable) addParam('Inserts (Z)', _teethCtrl, 'count');
        addParam(_isIndexable ? 'Feed per insert (fz)' : 'Feed (f)', _feedCtrl,
            _isIndexable ? uFeedTooth : uFeedRev);
        addParam('Feed rate (Vf)', _feedRateCtrl, uFeedRate);
        addParam('Hole depth', _lengthCtrl, uLength);
        addParam('No. of Holes', _holesCtrl, 'holes');
        break;
      case Operation.milling:
        addParam('Diameter (D)', _diameterCtrl, uDiameter);
        addParam('Cutting speed (Vc)', _speedCtrl, uSpeed);
        addParam('Spindle speed (n)', _rpmCtrl, 'RPM');
        addParam(
            _isIndexable ? 'Inserts (Z)' : 'Teeth (Z)', _teethCtrl, 'count');
        addParam('Feed per tooth (fz)', _feedCtrl, uFeedTooth);
        addParam('Feed rate (Vf)', _feedRateCtrl, uFeedRate);
        addParam('Depth of cut (ap)', _depthCtrl, uDepth);
        addParam('Width of cut (ae)', _widthCtrl, uDepth);
        addParam('Pass length', _lengthCtrl, uLength);
        addParam('No. of Passes', _passesCtrl, 'passes');
        if (_isIndexable) {
          addParam('Tool Price', _toolPriceCtrl, '');
          addParam('Avg. Life/Edge (N)', _toolLifeCtrl, 'pcs');
          addParam('Cutting Edges (Ce)', _edgesCtrl, 'edges');
        }
        break;
      case Operation.tapping:
        addParam('Tap diameter (D)', _diameterCtrl, uDiameter);
        addParam('Pitch (P)', _feedCtrl, uPitch);
        addParam('Cutting speed (Vc)', _speedCtrl, uSpeed);
        addParam('Spindle speed (n)', _rpmCtrl, 'RPM');
        addParam('Tapped depth', _lengthCtrl, uLength);
        addParam('No. of Holes', _holesCtrl, 'holes');
        break;
    }

    final resultRows = <List<String>>[];
    final chartStats = <(String, double, String)>[];
    void addResult(String label, double? value, String unit,
        {bool chart = false}) {
      if (value == null) return;
      final valueText = unit.isEmpty
          ? value.toStringAsFixed(2)
          : '${value.toStringAsFixed(2)} $unit';
      resultRows.add([_pdfSafe(label), _pdfSafe(valueText)]);
      if (chart) chartStats.add((label, value, unit));
    }

    addResult('Feed rate', _feedRate, uFeedRate, chart: true);
    addResult('Material removal rate', _mrr, uMrr, chart: true);
    addResult('Recommended drill size', _drillSize, 'mm', chart: true);
    addResult('Cycle time', _time, 'min', chart: true);
    addResult('Total cycle time', _totalTime, 'min', chart: true);
    addResult('Cost per component (CPC)', _cpc, '');
    if (_material != null) {
      addResult('Specific cutting force (kc)', _kc, 'N/mm2');
      addResult('Main cutting force (Fc)', _cuttingForce, 'N');
      addResult('Torque (Mc)', _torque, 'Nm');
      addResult('Power (Pmot)', _power, 'kW');
    }

    doc.addPage(
      pw.Page(
        build: (context) => pw.Stack(
          children: [
            if (watermark != null)
              pw.Positioned.fill(
                child: pw.Center(
                  child: pw.Transform.rotate(
                    angle: 0.5,
                    child: pw.Opacity(
                      opacity: 0.08,
                      child: pw.Image(watermark, width: 260),
                    ),
                  ),
                ),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('YG Machining Calculator',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: brand)),
                pw.SizedBox(height: 2),
                pw.Text(
                    _pdfSafe('${widget.meta.label}'
                        '${(_operation == Operation.drilling || _operation == Operation.milling) ? " (${_isIndexable ? "Indexable" : "Solid Carbide"})" : ""}'
                        ' - '
                        '${_units == Units.metric ? "Metric" : "Imperial"}'
                        '${_material != null ? " - ${_materialDisplayName ?? _material!.description}" : ""}'),
                    style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 18),
                pw.Text('Parameters',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: const ['Parameter', 'Value'],
                  data: paramRows,
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: brand),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellHeight: 22,
                ),
                pw.SizedBox(height: 18),
                pw.Text('Results',
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: const ['Result', 'Value'],
                  data: resultRows,
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: pw.BoxDecoration(color: brand),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellHeight: 22,
                ),
                if (chartStats.isNotEmpty) ...[
                  pw.SizedBox(height: 14),
                  _pdfBarChart(chartStats, brand),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'yg_${_operation.name}_report.pdf',
    );
  }

  // ============================================================
  // UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        toolbarHeight: 48,
        foregroundColor: _C.textDark,
        bottom: const TopStrip(),
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _C.cardAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.meta.iconData, color: _C.brand, size: 16),
            ),
            const SizedBox(width: 10),
            Text(widget.meta.label,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _C.textDark)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export / share as PDF',
            color: _C.brand,
            onPressed: _rpm != null ? _exportPdf : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionLabel('UNITS'),
            _unitsSlider(),
            if (_operation != Operation.tapping) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel('MATERIAL (OPTIONAL)'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MaterialReferenceScreen()),
                        );
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View data reference',
                            style: TextStyle(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          Icon(Icons.arrow_forward, size: 12, color: _accent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _materialPicker(),
            ],
            const SizedBox(height: 14),
            if (_operation == Operation.drilling ||
                _operation == Operation.milling)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel('PARAMETERS'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _C.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isIndexable ? 'Indexable' : 'Solid Carbide',
                        style: TextStyle(
                          color: _C.brand,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              _sectionLabel('PARAMETERS'),
            _card(child: _buildInputFields()),
            const SizedBox(height: 14),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.brand,
                backgroundColor: _C.brand.withOpacity(0.06),
                side: const BorderSide(color: _C.brand, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              onPressed: _clear,
              child: const Text('Clear'),
            ),
            const SizedBox(height: 14),
            if (_rpm != null || _cpc != null) _buildResults(),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(
          text,
          style: const TextStyle(
            color: _C.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }

  // Tab-bar style Metric/Imperial switch — solid accent background,
  // white text for both, with a thin white underline that slides to
  // whichever side is selected (matches the Drilling/Turning tabs
  // in the reference).
  Widget _unitsSlider() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _units = Units.metric);
                        _recalculate();
                      },
                      child: Center(
                        child: Text(
                          'Metric',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: _units == Units.metric
                                ? FontWeight.w800
                                : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _units = Units.imperial);
                        _recalculate();
                      },
                      child: Center(
                        child: Text(
                          'Imperial',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: _units == Units.imperial
                                ? FontWeight.w800
                                : FontWeight.w500,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: _units == Units.metric
                    ? Alignment.bottomLeft
                    : Alignment.bottomRight,
                child: Container(
                  width: segmentWidth,
                  height: 2.5,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _toggleButton(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _accent : _C.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _accent : _C.border),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : _C.textMuted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ---- material picker: opens a grouped list in a bottom sheet ----
  Widget _materialPicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _openMaterialPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_material != null)
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: materialBadgeColor(_material!.group),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _material!.group[0],
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            Expanded(
              child: _material == null
                  ? const Text(
                      'Select material for force, torque & power',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _C.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _materialDisplayName ?? _material!.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _C.textDark,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700),
                        ),
                        if (_material!.rmMax > 0)
                          Text(
                            'Rm ${_material!.rmMin.toInt()}–${_material!.rmMax.toInt()} N/mm²',
                            style: const TextStyle(
                                color: _C.textMuted, fontSize: 10),
                          ),
                      ],
                    ),
            ),
            if (_material != null)
              InkWell(
                onTap: () {
                  setState(() {
                    _material = null;
                    _materialDisplayName = null;
                  });
                  _recalculate();
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: _C.textMuted),
                ),
              )
            else
              const Icon(Icons.chevron_right, size: 20, color: _C.textMuted),
          ],
        ),
      ),
    );
  }

  void _openMaterialPicker() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final query = searchCtrl.text.trim().toLowerCase();
            final searching = query.isNotEmpty;
            final results = searching
                ? kNamedMaterials
                    .where((m) =>
                        m.name.toLowerCase().contains(query) ||
                        m.sae.toLowerCase().contains(query) ||
                        m.din.toLowerCase().contains(query) ||
                        m.en.toLowerCase().contains(query) ||
                        m.refs.toLowerCase().contains(query))
                    .take(60)
                    .toList()
                : <NamedMaterial>[];

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select material',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _C.textDark),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: searchCtrl,
                            onChanged: (_) => setModalState(() {}),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  'Search alloy, SAE, DIN, or EN, e.g. "4140", "EN19"',
                              hintStyle: const TextStyle(
                                  fontSize: 12, color: _C.textMuted),
                              filled: true,
                              fillColor: _C.cardAlt,
                              prefixIcon: const Icon(Icons.search,
                                  size: 18, color: _C.textMuted),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (!searching) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'OR BROWSE BY GENERIC GROUP',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: _C.textMuted,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: searching
                          ? _namedMaterialList(ctx, results)
                          : _genericGroupList(ctx),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Specific named alloys (from the linked CSV), filtered by search.
  Widget _namedMaterialList(BuildContext ctx, List<NamedMaterial> results) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No matching alloy found.',
            style: TextStyle(color: _C.textMuted, fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border),
      itemBuilder: (_, i) {
        final nm = results[i];
        final spec = materialSpecFor(nm);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: materialBadgeColor(nm.walterGroup),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(nm.walterGroup.isNotEmpty ? nm.walterGroup[0] : '?',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          title: Text(nm.name,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              nm.subGroup,
              if (nm.din.isNotEmpty) 'DIN ${nm.din}',
              if (nm.en.isNotEmpty) nm.en
            ].join('  ·  '),
            style: const TextStyle(fontSize: 11, color: _C.textMuted),
          ),
          onTap: spec == null
              ? null
              : () {
                  setState(() {
                    _material = spec;
                    _materialDisplayName = nm.name;
                  });
                  _recalculate();
                  Navigator.pop(ctx);
                },
        );
      },
    );
  }

  // The 33 generic Walter machining groups, browsable directly.
  Widget _genericGroupList(BuildContext ctx) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: kMaterials.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: _C.border),
      itemBuilder: (_, i) {
        final m = kMaterials[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: materialBadgeColor(m.group),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(m.group[0],
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          title: Text(m.description,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(
            m.rmMax > 0
                ? '${m.group}  ·  Rm ${m.rmMin.toInt()}-${m.rmMax.toInt()} N/mm²'
                : m.group,
            style: const TextStyle(fontSize: 11, color: _C.textMuted),
          ),
          onTap: () {
            setState(() {
              _material = m;
              _materialDisplayName = null;
            });
            _recalculate();
            Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Widget _field(TextEditingController ctrl, String label, String unit,
      {String? symbol, bool computed = false, FocusNode? focusNode}) {
    final displayLabel = symbol != null ? '$label [$symbol]' : label;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: computed ? _accent : _C.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.only(bottom: 6),
                    border: UnderlineInputBorder(
                        borderSide: BorderSide(color: _C.border)),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _C.border)),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: _accent, width: 1.5)),
                    hintText: '0',
                    hintStyle: TextStyle(
                      color: _C.textMuted.withOpacity(0.35),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 6, bottom: 8),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      color: _C.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Arranges parameter fields into 2-per-row pairs — matching the
  // Diameter/Cutting-speed style table pairing from the reference —
  // instead of a boxed grid.
  Widget _fieldGrid(List<Widget> fields) {
    const gap = 14.0;
    final rows = <Widget>[];
    for (int i = 0; i < fields.length; i += 2) {
      final chunk =
          fields.sublist(i, i + 2 > fields.length ? fields.length : i + 2);
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: gap),
              Expanded(child: chunk[j]),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildInputFields() {
    switch (_operation) {
      case Operation.turning:
        return _fieldGrid([
          _field(_diameterCtrl, 'Diameter', uDiameter, symbol: 'D'),
          _field(_speedCtrl, 'Speed', uSpeed,
              symbol: 'Vc',
              computed: _rpmIsDriving,
              focusNode: _speedFocusNode),
          _field(_rpmCtrl, 'Speed', 'RPM',
              symbol: 'n', computed: !_rpmIsDriving, focusNode: _rpmFocusNode),
          _field(_feedCtrl, 'Feed', uFeedRev,
              symbol: 'f',
              computed: _feedRateIsDriving,
              focusNode: _feedFocusNode),
          _field(_feedRateCtrl, 'Feed rate', uFeedRate,
              symbol: 'Vf',
              computed: !_feedRateIsDriving,
              focusNode: _feedRateFocusNode),
          _field(_depthCtrl, 'Depth', uDepth, symbol: 'ap'),
          _field(_lengthCtrl, 'Length (opt)', uLength),
          _field(_passesCtrl, 'No. of Passes', 'passes', symbol: 'Qty'),
          _field(_toolPriceCtrl, 'Tool Price', ''),
          _field(_toolLifeCtrl, 'Avg. Life/Edge', 'pcs', symbol: 'N'),
          _field(_edgesCtrl, 'Cutting Edges', 'edges', symbol: 'Ce'),
        ]);
      case Operation.drilling:
        return _fieldGrid([
          _field(_diameterCtrl, 'Diameter', uDiameter, symbol: 'D'),
          _field(_speedCtrl, 'Speed', uSpeed,
              symbol: 'Vc',
              computed: _rpmIsDriving,
              focusNode: _speedFocusNode),
          _field(_rpmCtrl, 'Speed', 'RPM',
              symbol: 'n', computed: !_rpmIsDriving, focusNode: _rpmFocusNode),
          if (_isIndexable) _field(_teethCtrl, 'Inserts', 'count', symbol: 'Z'),
          _field(_feedCtrl, _isIndexable ? 'Feed per insert' : 'Feed',
              _isIndexable ? uFeedTooth : uFeedRev,
              symbol: _isIndexable ? 'fz' : 'f',
              computed: _feedRateIsDriving,
              focusNode: _feedFocusNode),
          _field(_feedRateCtrl, 'Feed rate', uFeedRate,
              symbol: 'Vf',
              computed: !_feedRateIsDriving,
              focusNode: _feedRateFocusNode),
          _field(_lengthCtrl, 'Depth (opt)', uLength),
          _field(_holesCtrl, 'No. of Holes', 'holes', symbol: 'Qty'),
        ]);
      case Operation.milling:
        return _fieldGrid([
          _field(_diameterCtrl, 'Diameter', uDiameter, symbol: 'D'),
          _field(_speedCtrl, 'Speed', uSpeed,
              symbol: 'Vc',
              computed: _rpmIsDriving,
              focusNode: _speedFocusNode),
          _field(_rpmCtrl, 'Speed', 'RPM',
              symbol: 'n', computed: !_rpmIsDriving, focusNode: _rpmFocusNode),
          _field(_teethCtrl, _isIndexable ? 'Inserts' : 'Teeth', 'count',
              symbol: 'Z'),
          _field(_feedCtrl, 'Feed', uFeedTooth,
              symbol: 'fz',
              computed: _feedRateIsDriving,
              focusNode: _feedFocusNode),
          _field(_feedRateCtrl, 'Feed rate', uFeedRate,
              symbol: 'Vf',
              computed: !_feedRateIsDriving,
              focusNode: _feedRateFocusNode),
          _field(_depthCtrl, 'Depth', uDepth, symbol: 'ap'),
          _field(_widthCtrl, 'Width', uDepth, symbol: 'ae'),
          _field(_lengthCtrl, 'Length (opt)', uLength),
          _field(_passesCtrl, 'No. of Passes', 'passes', symbol: 'Qty'),
          if (_isIndexable) ...[
            _field(_toolPriceCtrl, 'Tool Price', ''),
            _field(_toolLifeCtrl, 'Avg. Life/Edge', 'pcs', symbol: 'N'),
            _field(_edgesCtrl, 'Cutting Edges', 'edges', symbol: 'Ce'),
          ],
        ]);
      case Operation.tapping:
        return Column(children: [
          _tapTypeRow(),
          const SizedBox(height: 12),
          if (_units == Units.metric) ...[
            _fieldGrid([
              _field(_diameterCtrl, 'Diameter', uDiameter, symbol: 'D'),
              _field(_feedCtrl, 'Pitch', uPitch, symbol: 'P'),
              _field(_speedCtrl, 'Speed', uSpeed,
                  symbol: 'Vc',
                  computed: _rpmIsDriving,
                  focusNode: _speedFocusNode),
              _field(_rpmCtrl, 'Speed', 'RPM',
                  symbol: 'n',
                  computed: !_rpmIsDriving,
                  focusNode: _rpmFocusNode),
              _field(_lengthCtrl, 'Depth (opt)', uLength),
              _field(_holesCtrl, 'No. of Holes', 'holes', symbol: 'Qty'),
            ]),
          ] else ...[
            _threadStandardRow(),
            const SizedBox(height: 12),
            _threadSizeField(),
            const SizedBox(height: 12),
            _fieldGrid([
              _field(_speedCtrl, 'Speed', uSpeed,
                  symbol: 'Vc',
                  computed: _rpmIsDriving,
                  focusNode: _speedFocusNode),
              _field(_rpmCtrl, 'Speed', 'RPM',
                  symbol: 'n',
                  computed: !_rpmIsDriving,
                  focusNode: _rpmFocusNode),
              _field(_lengthCtrl, 'Depth (opt)', uLength),
              _field(_holesCtrl, 'No. of Holes', 'holes', symbol: 'Qty'),
            ]),
          ],
          if (_isFormTap)
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'Form/roll tap drill sizes vary more by tap manufacturer than '
                'cut tap sizes do — this uses a commonly recommended ~65% '
                'engagement. Check your tap maker\'s chart for critical work.',
                style:
                    TextStyle(color: _C.textMuted, fontSize: 11, height: 1.3),
              ),
            ),
          if (_units == Units.imperial && _threadStandard == 'NPT')
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'NPT is a tapered thread — its true tap drill size is normally '
                'read from a manufacturer chart. This uses the same '
                'diameter-minus-pitch rule as the other standards, off NPT\'s '
                'standard nominal pipe OD, as an approximation.',
                style:
                    TextStyle(color: _C.textMuted, fontSize: 11, height: 1.3),
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Drill size is always shown in mm, regardless of this toggle.',
              style: TextStyle(color: _C.textMuted, fontSize: 11),
            ),
          ),
        ]);
    }
  }

  Widget _tapTypeRow() {
    return Row(
      children: [
        Expanded(
          child: _toggleButton(
            label: 'Cut Tap',
            selected: !_isFormTap,
            onTap: () {
              setState(() => _isFormTap = false);
              _recalculate();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _toggleButton(
            label: 'Form (Roll) Tap',
            selected: _isFormTap,
            onTap: () {
              setState(() => _isFormTap = true);
              _recalculate();
            },
          ),
        ),
      ],
    );
  }

  Widget _threadStandardRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kImperialThreadStandardNames.map((std) {
        final selected = _threadStandard == std;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _threadStandard = std;
              _selectedThreadSize = null;
            });
            _recalculate();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _C.brand : _C.cardAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              std,
              style: TextStyle(
                color: selected ? Colors.white : _C.textDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Whole TPI values show clean ("20"); fractional ones (NPT's 11.5)
  // keep one decimal place.
  String _fmtTpi(double tpi) {
    return tpi == tpi.roundToDouble()
        ? tpi.toStringAsFixed(0)
        : tpi.toStringAsFixed(1);
  }

  Widget _threadSizeField() {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _openThreadSizePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _C.cardAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedThreadSize == null
                    ? 'Select $_threadStandard size'
                    : '$_threadStandard ${_selectedThreadSize!.label}  ·  '
                        '${_selectedThreadSize!.diameterMm.toStringAsFixed(2)} mm dia  ·  '
                        '${_fmtTpi(_selectedThreadSize!.tpi)} TPI',
                style: TextStyle(
                  color:
                      _selectedThreadSize == null ? _C.textMuted : _C.textDark,
                  fontSize: 13,
                  fontWeight: _selectedThreadSize == null
                      ? FontWeight.w500
                      : FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _C.textMuted),
          ],
        ),
      ),
    );
  }

  void _openThreadSizePicker() {
    final sizes = kThreadStandards[_threadStandard]!;
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$_threadStandard sizes',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _C.textDark),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sizes.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _C.border),
                    itemBuilder: (_, i) {
                      final s = sizes[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.label,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${s.diameterMm.toStringAsFixed(2)} mm dia  ·  '
                          '${_fmtTpi(s.tpi)} TPI',
                          style: const TextStyle(
                              fontSize: 12, color: _C.textMuted),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedThreadSize = s;
                            // Fields are populated in inches — this picker only
                            // shows when Units is Imperial, and the RPM/feed
                            // formulas for that mode expect inch inputs.
                            _diameterCtrl.text =
                                (s.diameterMm / 25.4).toStringAsFixed(4);
                            _feedCtrl.text =
                                (s.pitchMm / 25.4).toStringAsFixed(4);
                          });
                          _recalculate();
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResults() {
    final chartable = <(String, double, String)>[
      if (_feedRate != null) ('Feed rate', _feedRate!, uFeedRate),
      if (_mrr != null) ('Material removal rate', _mrr!, uMrr),
      if (_drillSize != null) ('Recommended drill size', _drillSize!, 'mm'),
      if (_time != null) ('Cycle time', _time!, 'min'),
      if (_totalTime != null) ('Total cycle time', _totalTime!, 'min'),
    ];
    final primary = <(String, double, String)>[
      ...chartable,
      if (_cpc != null) ('Cost per component (CPC)', _cpc!, ''),
    ];
    final materialStats = <(String, double, String)>[
      if (_kc != null) ('Specific cutting force kc', _kc!, 'N/mm²'),
      if (_cuttingForce != null) ('Main cutting force Fc', _cuttingForce!, 'N'),
      if (_torque != null) ('Torque Mc', _torque!, 'Nm'),
      if (_power != null) ('Power Pmot', _power!, 'kW'),
    ];
    final hasMaterialStats = _material != null && materialStats.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent, const Color(0xFFA80E18)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _accent.withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'RESULTS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              if (hasMaterialStats)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () =>
                      setState(() => _resultsExpanded = !_resultsExpanded),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _resultsExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._gradientStatRows(primary),
          if (hasMaterialStats && _resultsExpanded) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Colors.white24, height: 1),
            ),
            Text(
              'MATERIAL — ${_material!.description}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            ..._gradientStatRows(materialStats),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Assumes 90° entry angle and 80% machine efficiency.',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
          ],
          if (chartable.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Colors.white24, height: 1),
            ),
            _inAppBarChart(chartable),
          ],
        ],
      ),
    );
  }

  // Lays result stats out 2-per-row, matching the reference panel's
  // paired grid (Metal removal rate / Cut time, Torque / Power).
  List<Widget> _gradientStatRows(List<(String, double, String)> stats) {
    final rows = <Widget>[];
    for (int i = 0; i < stats.length; i += 2) {
      final chunk =
          stats.sublist(i, i + 2 > stats.length ? stats.length : i + 2);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _gradientStat(chunk[0])),
              if (chunk.length > 1) ...[
                const SizedBox(width: 16),
                Expanded(child: _gradientStat(chunk[1])),
              ],
            ],
          ),
        ),
      );
    }
    return rows;
  }

  // A simple bar chart shown right in the results panel — each bar's
  // height is scaled to that stat's own value relative to the
  // largest value in the set, with the number and unit labeled so it
  // stays meaningful even though the metrics use different units.
  Widget _inAppBarChart(List<(String, double, String)> stats) {
    const maxBarHeight = 70.0;
    final maxVal = stats.map((s) => s.$2).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stats[i].$2.toStringAsFixed(1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxVal > 0
                        ? (stats[i].$2 / maxVal) * maxBarHeight + 4
                        : 4,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stats[i].$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    stats[i].$3,
                    style: const TextStyle(color: Colors.white54, fontSize: 8),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradientStat((String, double, String) item) {
    final (label, value, unit) = item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 3),
        Text(
          unit.isEmpty
              ? value.toStringAsFixed(2)
              : '${value.toStringAsFixed(2)} $unit',
          style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

// ============================================================
// MATERIAL REFERENCE SCREEN
// A checkable data sheet: every alloy from the linked CSV, its
// resolved Walter machining group, and that group's specific
// cutting force (kc1.1) and exponent (mc) — so the numbers the
// calculator uses aren't a black box.
// ============================================================
class MaterialReferenceScreen extends StatefulWidget {
  const MaterialReferenceScreen({super.key});

  @override
  State<MaterialReferenceScreen> createState() =>
      _MaterialReferenceScreenState();
}

class _MaterialReferenceScreenState extends State<MaterialReferenceScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _hardnessPill(String text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: _C.textDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final rows = query.isEmpty
        ? kNamedMaterials
        : kNamedMaterials
            .where((m) =>
                m.name.toLowerCase().contains(query) ||
                m.sae.toLowerCase().contains(query) ||
                m.din.toLowerCase().contains(query) ||
                m.en.toLowerCase().contains(query) ||
                m.refs.toLowerCase().contains(query) ||
                m.subGroup.toLowerCase().contains(query))
            .toList();

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        foregroundColor: _C.textDark,
        bottom: const TopStrip(),
        title: const Text('Material data reference',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search alloy, SAE, DIN, EN, or category',
                    hintStyle:
                        const TextStyle(fontSize: 12, color: _C.textMuted),
                    filled: true,
                    fillColor: _C.cardAlt,
                    prefixIcon:
                        const Icon(Icons.search, size: 18, color: _C.textMuted),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${rows.length} of ${kNamedMaterials.length} materials',
                    style: const TextStyle(fontSize: 11, color: _C.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No matches.',
                        style: TextStyle(color: _C.textMuted, fontSize: 13)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: _C.border),
                    itemBuilder: (_, i) {
                      final nm = rows[i];
                      final spec = materialSpecFor(nm);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              margin: const EdgeInsets.only(top: 2, right: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: materialBadgeColor(nm.walterGroup),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                nm.walterGroup.isNotEmpty
                                    ? nm.walterGroup[0]
                                    : '?',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nm.name,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  if (nm.hardnessHrc.isNotEmpty ||
                                      nm.hardnessHrb.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Wrap(
                                        spacing: 6,
                                        children: [
                                          if (nm.hardnessHrc.isNotEmpty)
                                            _hardnessPill(
                                                'HRC ${nm.hardnessHrc}',
                                                materialBadgeColor(
                                                    nm.walterGroup)),
                                          if (nm.hardnessHrb.isNotEmpty)
                                            _hardnessPill(
                                                'HRB ${nm.hardnessHrb}',
                                                _C.cardAlt),
                                        ],
                                      ),
                                    ),
                                  Text(
                                    nm.subGroup,
                                    style: const TextStyle(
                                        fontSize: 11, color: _C.textMuted),
                                  ),
                                  if (nm.sae.isNotEmpty ||
                                      nm.din.isNotEmpty ||
                                      nm.en.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        [
                                          if (nm.sae.isNotEmpty)
                                            'SAE ${nm.sae}',
                                          if (nm.din.isNotEmpty)
                                            'DIN ${nm.din}',
                                          if (nm.en.isNotEmpty) nm.en,
                                        ].join('  ·  '),
                                        style: const TextStyle(
                                            fontSize: 11, color: _C.textMuted),
                                      ),
                                    ),
                                  if (nm.machinability.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Machinability ${nm.machinability}',
                                        style: const TextStyle(
                                            fontSize: 11, color: _C.textMuted),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(nm.walterGroup,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _C.brand)),
                                const SizedBox(height: 2),
                                if (spec != null) ...[
                                  Text('kc1.1 ${spec.kc11.toInt()} N/mm²',
                                      style: const TextStyle(
                                          fontSize: 11, color: _C.textMuted)),
                                  Text('mc ${spec.mc}',
                                      style: const TextStyle(
                                          fontSize: 11, color: _C.textMuted)),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TOLERANCE SCREEN — ISO hole & shaft fit calculator
// ============================================================
class ToleranceScreen extends StatefulWidget {
  const ToleranceScreen({super.key});

  @override
  State<ToleranceScreen> createState() => _ToleranceScreenState();
}

class _ToleranceScreenState extends State<ToleranceScreen> {
  final _sizeCtrl = TextEditingController(text: '10');
  int _holeGrade = 7;
  String _holeLetter = 'H';
  int _shaftGrade = 6;
  String _shaftLetter = 'g';

  // Which side (Hole or Shaft) the wheel pickers and big readout
  // are currently showing/editing — switched via the bottom tabs.
  bool _showingHole = true;

  static const List<int> _grades = [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

  // Picker scroll controllers are created ONCE and reused — never
  // rebuilt inline during build(). Recreating a FixedExtentScrollController
  // on every keystroke (which happened when this screen rebuilt on
  // every character typed into Nominal Size) fights with the picker's
  // internal state and was freezing the on-screen text input.
  late final FixedExtentScrollController _holeLetterCtrl;
  late final FixedExtentScrollController _holeGradeCtrl;
  late final FixedExtentScrollController _shaftLetterCtrl;
  late final FixedExtentScrollController _shaftGradeCtrl;

  @override
  void initState() {
    super.initState();
    _holeLetterCtrl = FixedExtentScrollController(
        initialItem: kHoleLetters.indexOf(_holeLetter));
    _holeGradeCtrl =
        FixedExtentScrollController(initialItem: _grades.indexOf(_holeGrade));
    _shaftLetterCtrl = FixedExtentScrollController(
        initialItem: kShaftLetters.indexOf(_shaftLetter));
    _shaftGradeCtrl =
        FixedExtentScrollController(initialItem: _grades.indexOf(_shaftGrade));
    // Only the live number readout + fit card need to react to typing —
    // AnimatedBuilder below scopes the rebuild to just that subtree,
    // so the TextField and pickers are never torn down mid-keystroke.
  }

  @override
  void dispose() {
    _sizeCtrl.dispose();
    _holeLetterCtrl.dispose();
    _holeGradeCtrl.dispose();
    _shaftLetterCtrl.dispose();
    _shaftGradeCtrl.dispose();
    super.dispose();
  }

  String _fmtDev(double microns) {
    final mm = microns / 1000;
    final sign = mm >= 0 ? '+' : '';
    return '$sign${mm.toStringAsFixed(3)}';
  }

  @override
  Widget build(BuildContext context) {
    final letters = _showingHole ? kHoleLetters : kShaftLetters;
    final letterCtrl = _showingHole ? _holeLetterCtrl : _shaftLetterCtrl;
    final gradeCtrl = _showingHole ? _holeGradeCtrl : _shaftGradeCtrl;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        foregroundColor: _C.textDark,
        bottom: const TopStrip(),
        title: const Text('Tolerance',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ---- big readout banner (rebuilds live as you type) ----
          AnimatedBuilder(
            animation: _sizeCtrl,
            builder: (context, _) {
              final D = double.tryParse(_sizeCtrl.text);
              final letter = _showingHole ? _holeLetter : _shaftLetter;
              final grade = _showingHole ? _holeGrade : _shaftGrade;
              (double, double)? dev;
              if (D != null && D > 0) {
                dev = _showingHole
                    ? holeDeviation(D, _holeGrade, _holeLetter)
                    : shaftDeviation(D, _shaftGrade, _shaftLetter);
              }
              return Container(
                width: double.infinity,
                color: _C.brand,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          D != null ? _trimZero(D) : '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (dev != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_fmtDev(dev.$1),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2)),
                                Text(_fmtDev(dev.$2),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        height: 1.2)),
                              ],
                            ),
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('$letter$grade',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Text('Nominal Size',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: _sizeCtrl,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                            decoration: InputDecoration(
                              suffixText: 'mm',
                              suffixStyle: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white54),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          // ---- fit summary + wheel pickers (scrollable if needed) ----
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _sizeCtrl,
                    builder: (context, _) {
                      final D = double.tryParse(_sizeCtrl.text);
                      if (D == null || D <= 0) return const SizedBox.shrink();
                      final holeDevBoth =
                          holeDeviation(D, _holeGrade, _holeLetter);
                      final shaftDevBoth =
                          shaftDeviation(D, _shaftGrade, _shaftLetter);
                      final holeMax = D + holeDevBoth.$1 / 1000;
                      final holeMin = D + holeDevBoth.$2 / 1000;
                      final shaftMax = D + shaftDevBoth.$1 / 1000;
                      final shaftMin = D + shaftDevBoth.$2 / 1000;
                      final maxClearance = holeMax - shaftMin;
                      final minClearance = holeMin - shaftMax;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: _fitCard(maxClearance, minClearance),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: Row(
                      children: [
                        Expanded(
                          child: _wheel(
                            controller: letterCtrl,
                            items: letters,
                            onChanged: (i) {
                              setState(() {
                                if (_showingHole) {
                                  _holeLetter = letters[i];
                                } else {
                                  _shaftLetter = letters[i];
                                }
                              });
                            },
                          ),
                        ),
                        Container(width: 1, color: _C.border),
                        Expanded(
                          child: _wheel(
                            controller: gradeCtrl,
                            items: _grades.map((g) => '$g').toList(),
                            onChanged: (i) {
                              setState(() {
                                if (_showingHole) {
                                  _holeGrade = _grades[i];
                                } else {
                                  _shaftGrade = _grades[i];
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Shaft fundamental deviations (c/d/e/f/g/k/n/p/s/u) are standard '
                      'reference figures for common preferred fits. Hole letters are '
                      'mirrored from the same table (exact through grade IT8). Verify '
                      'against ISO 286-2 before using for production tolerancing.',
                      style: TextStyle(
                          color: _C.textMuted, fontSize: 10, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ---- Hole / Shaft tabs ----
          Row(
            children: [
              Expanded(
                  child: _tab('Hole', _showingHole,
                      () => setState(() => _showingHole = true))),
              Expanded(
                  child: _tab('Shaft', !_showingHole,
                      () => setState(() => _showingHole = false))),
            ],
          ),
        ],
      ),
    );
  }

  String _fitCategory() {
    if (['c', 'd', 'e', 'f', 'g'].contains(_shaftLetter))
      return 'Clearance fit';
    if (['k', 'n'].contains(_shaftLetter)) return 'Transition fit';
    if (['p', 's', 'u'].contains(_shaftLetter)) return 'Interference fit';
    return 'Reference fit'; // h or js
  }

  Widget _fitCard(double maxClearance, double minClearance) {
    return Container(
      decoration: BoxDecoration(
        color: _C.brand.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.brand.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$_holeLetter$_holeGrade / $_shaftLetter$_shaftGrade fit',
                    style: const TextStyle(color: _C.textMuted, fontSize: 13)),
                Text(_fitCategory(),
                    style: TextStyle(
                        color: _C.brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ],
            ),
          ),
          const Divider(height: 1, color: _C.border),
          _row(maxClearance >= 0 ? 'Max clearance' : 'Max interference',
              '${maxClearance.abs().toStringAsFixed(3)} mm'),
          _row(minClearance >= 0 ? 'Min clearance' : 'Min interference',
              '${minClearance.abs().toStringAsFixed(3)} mm'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: _C.textMuted, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: _C.brand, fontWeight: FontWeight.w800, fontSize: 14)),
        ],
      ),
    );
  }

  String _trimZero(double d) {
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        color: selected ? _C.brand : const Color(0xFF3A3D44),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required List<String> items,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      itemExtent: 46,
      scrollController: controller,
      onSelectedItemChanged: onChanged,
      selectionOverlay: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _C.brand, width: 1.5),
          color: _C.brand.withOpacity(0.06),
        ),
      ),
      children: [
        for (int i = 0; i < items.length; i++)
          Container(
            color: i.isEven ? _C.card : _C.cardAlt,
            alignment: Alignment.center,
            child: Text(
              items[i],
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _C.textDark),
            ),
          ),
      ],
    );
  }
}
