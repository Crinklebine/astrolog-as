/*
** Astrolog (Version 8.00) File: data.cpp
**
** IMPORTANT NOTICE: Astrolog and all chart display routines and anything
** not enumerated below used in this program are Copyright (C) 1991-2026 by
** Walter D. Pullen (Astara@msn.com, http://www.astrolog.org/astrolog.htm).
** Permission is granted to freely use, modify, and distribute these
** routines provided these credits and notices remain unmodified with any
** altered or distributed versions of the program.
**
** The main ephemeris databases and calculation routines are from the
** library SWISS EPHEMERIS and are programmed and copyright 1997-2008 by
** Astrodienst AG. Use of that source code is subject to license for Swiss
** Ephemeris Free Edition at https://www.astro.com/swisseph/swephinfo_e.htm.
** This copyright notice must not be changed or removed by any user of this
** program.
**
** Additional ephemeris databases and formulas are from the calculation
** routines in the program PLACALC and are programmed and Copyright (C)
** 1989,1991,1993 by Astrodienst AG and Alois Treindl (alois@astro.ch). The
** use of that source code is subject to regulations made by Astrodienst
** Zurich, and the code is not in the public domain. This copyright notice
** must not be changed or removed by any user of this program.
**
** The original planetary calculation routines used in this program have
** been copyrighted and the initial core of this program was mostly a
** conversion to C of the routines created by James Neely as listed in
** 'Manual of Computer Programming for Astrologers', by Michael Erlewine,
** available from Matrix Software.
**
** Atlas composed using data from https://www.geonames.org/ licensed under a
** Creative Commons Attribution 4.0 License. Time zone changes composed using
** public domain TZ database: https://data.iana.org/time-zones/tz-link.html
**
** The PostScript code within the core graphics routines are programmed
** and Copyright (C) 1992-1993 by Brian D. Willoughby (brianw@sounds.wa.com).
**
** More formally: This program is free software; you can redistribute it
** and/or modify it under the terms of the GNU General Public License as
** published by the Free Software Foundation; either version 2 of the
** License, or (at your option) any later version. This program is
** distributed in the hope that it will be useful and inspiring, but
** WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
** General Public License for more details, a copy of which is in the
** LICENSE.HTM file included with Astrolog, and at http://www.gnu.org
**
** Initial programming 8/28-30/1991.
** X Window graphics initially programmed 10/23-29/1991.
** PostScript graphics initially programmed 11/29-30/1992.
** Last code change made 5/28/2026.
*/

#include "astrolog.h"


/*
******************************************************************************
** Global Variables.
******************************************************************************
*/

US us = {

  // Chart types
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

  // Chart suboptions
  0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0,

  // Table chart types
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

  // Main flags
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
#ifdef EPHEM
  1,
#else
  0,
#endif
  0, 0, 0,

  // Main subflags
  0, 0, 0, 0, 0, 0,
#ifdef PLACALC
#ifndef SWISS
  1,
#else
  0,
#endif
#else
  0,
#endif // PLACALC
#ifdef EPHEM
  0,
#else
  1,
#endif
  0, 0, 0, 0, 0, 0, 0, 0,

  // Obscure flags
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
  1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,

  // Value settings
  ddDecanR,
  0,
  0,
  0,
  1,
  0,
  rcNone,
  0,
  DEFAULT_SYSTEM,
  hmPrime,
  DEFAULT_ASPECTS,
  oEar,
  0,
  0,
  1.0,
  0,
  -1,
  oSun,
  0,
  ptCast,
  DIVISIONS,
  SCREENWIDTH,
  0,
  0,
  0.0,
  15.0,
  {NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL},
  NULL,
  NULL,
  NULL,
  NULL,
  NULL,

  // Value subsettings
  0, 5, 200, cPart, 22, 0.0, 0.0, rDayInYear, 1.0, 0.5, ccNone, ccNone,
  24, 0, 0, rInvalid, 0.0, 0.0, 0.0, oEar, oEar, 0, 0, BIODAYS, 0, 0, 0,

  // AstroExpressions
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  NULL, NULL, NULL, NULL};

IS is = {
#ifdef SWITCHES
  fFalse,
#else
  fTrue,
#endif
  fFalse, fFalse, fFalse, fFalse, fFalse, fFalse, fFalse, fFalse, fFalse,
  NULL, {0,0,0,0,0,0,0,0,0}, NULL, NULL, NULL,
  0, cObj, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, -1, -1, 0, 0, 0,
  0, 0, 0, 0.0, 0.0, 0.0, 0.0, 0.0,
  NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, rAxis, 0.0, rInvalid, 0.0};

CI ciCore = {11, 19, 1971, HM(11, 1),     0.0, 8.0, DEFAULT_LOC, NULL, NULL};
CI ciMain = {-1, 0,  0,    0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CI ciTwin = {9,  11, 1991, HMS(0, 0, 38), 0.0, 0.0, DEFAULT_LOC, NULL, NULL};
CI ciThre = {-1, 0,  0,    0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CI ciFour = {-1, 0,  0,    0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CI ciFive = {-1, 0,  0,    0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CI ciHexa = {-1, 0,  0,    0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CI ciDefa = {-1, 0,  0,    0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CI ciTran = {1,  1,  2026, 0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CI ciSave = {5,  31, 2026, HMS(1,45,13),  1.0, 8.0, DEFAULT_LOC, NULL, NULL};
CI ciGreg = {10, 15, 1582, 0.0,           0.0, 0.0, 0.0, 0.0,    NULL, NULL};
CP cp0, cp1, cp2, cp3, cp4, cp5, cp6;

CI * CONST rgpci[cRing+1] = {&ciCore,
  &ciMain, &ciTwin, &ciThre, &ciFour, &ciFive, &ciHexa};
CP * CONST rgpcp[cRing+1] = {&cp0, &cp1, &cp2, &cp3, &cp4, &cp5, &cp6};
flag rgfProg[cRing+1] = {0, fFalse, fFalse, fFalse, fFalse, fFalse, fFalse};


/*
******************************************************************************
** Global Arrays.
******************************************************************************
*/

real force[objMax];
GridInfo *grid = NULL;
int rgobjList[objMax], rgobjList2[objMax], starname[cStar+1], kObjA[objMax];
char *szWheel[cRing+1] = {NULL, NULL, NULL, NULL, NULL, NULL, NULL};
real rStarBrightDef[cStar+1] = {-1.0}, rStarBright[cStar+1],
  rStarBrightDistDef[cStar+1];
char *szStarCustom[cStar+1];

// Restriction status of each object, as specified with -R switch.

byte ignore[objMax] = {1,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,                     // Planets
  0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,                  // Minors
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,               // Cusps
  1, 1, 1, 1, 1, 1, 1, 1, 1,                        // Uranians
  1, 1, 1, 1, 1, 1, 1, 1, 1,                        // Dwarfs
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // Moons
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  // Stars
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};

// Restriction of objects when transiting, as specified with -RT switch.

byte ignore2[objMax] = {1,
  0, 1, 0, 0, 0, 0, 0, 0, 0, 0,                     // Planets
  0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1,                  // Minors
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,               // Cusps
  1, 1, 1, 1, 1, 1, 1, 1, 1,                        // Uranians
  1, 1, 1, 1, 1, 1, 1, 1, 1,                        // Dwarfs
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // Moons
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  // Stars
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};

// Restriction status of each aspect, as specified with -RA switch.

byte ignorea[cAspect+1] = {0,
  0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

byte ignorez[arMax] = {0, 0, 0, 0, 1, 1}; // Restrictions for -Zd events.
byte ignore7[rrMax] = {0, 1, 1, 0, 1};    // Restrictions for rulership types.

byte ignoreMem[objMax], ignore2Mem[objMax], ignoreaMem[cAspect+1],
  ignorezMem[arMax], ignore7Mem[rrMax], ignorefMem[6];

// Gauquelin sector plus zones, as specified with -Yl switch.

byte pluszone[cSector+1] = {0,
  1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 1,
  1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1};


/*
******************************************************************************
** Global Tables.
******************************************************************************
*/

CONST char *szAppName = szAppNameCore;

CONST char *szSignName[cSign+1] = {"",
  "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
  "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"};

CONST char *szSignAbbrev[cSign+1] = {"",
  "Ar", "Ta", "Ge", "Cn", "Le", "Vi", "Li", "Sc", "Sg", "Cp", "Aq", "Pi"};

CONST char *szSignEnglish[cSign+1] = {"",
  "Ram", "Bull", "Twins", "Crab", "Lion", "Virgin",
  "Scales", "Scorpion", "Archer", "Sea Goat", "Water Bearer", "Fishes"};

CONST char *szHouseTradition[cSign+1] = {"",
  "Personality", "Money", "Communication", "Home",
  "Children", "Servants", "Marriage", "Death",
  "Long Journeys Over Water", "Career", "Friends", "Troubles"};

CONST char *szObjName[objMax+4] = {
  "Earth", "Sun", "Moon", "Mercury", "Venus", "Mars",       // Planets
  "Jupiter", "Saturn", "Uranus", "Neptune", "Pluto",
  "Chiron", "Ceres", "Pallas", "Juno", "Vesta",             // Asteroids
  "North Node", "South Node",                               // Nodes
  "Lilith", "Fortune", "Vertex", "East Point",              // Others
  "Ascendant", "2nd Cusp", "3rd Cusp", "Nadir",             // Cusps
  "5th Cusp", "6th Cusp", "Descendant", "8th Cusp",
  "9th Cusp", "Midheaven", "11th Cusp", "12th Cusp",
  "Vulcan", "Cupido", "Hades", "Zeus", "Kronos",            // Uranians
  "Apollon", "Admetos", "Vulkanus", "Poseidon",
  "Hygiea", "Pholus", "Eris", "Haumea", "Makemake",         // Dwarfs
  "Gonggong", "Quaoar", "Sedna", "Orcus",

  "Phobos", "Deimos",                                       // Moons
  "Ganymede", "Callisto", "Io", "Europa",
  "Titan", "Rhea", "Iapetus", "Dione",
  "Tethys", "Enceladus", "Mimas", "Hyperion",
  "Titania", "Oberon", "Umbriel", "Ariel", "Miranda",
  "Triton", "Proteus", "Nereid",
  "Charon", "Hydra", "Nix", "Kerberos", "Styx",
  "JupCOB", "SatCOB", "UraCOB", "NepCOB", "PluCOB",

  "Sirius", "Canopus", "Rigil Kent.", "Arcturus", "Vega",   // Stars
  "Capella", "Rigel", "Procyon", "Betelgeuse", "Achernar",
  "Agena", "Altair", "Acrux", "Aldebaran", "Antares",
  "Spica", "Pollux", "Fomalhaut", "Deneb", "Becrux",
  "Regulus", "Adara", "Castor", "Shaula", "Bellatrix",
  "Gacrux", "Alnath", "Alnilam", "Miaplacidus", "Alnair",
  "Alioth", "Dubhe", "Wezen", "Kaus Austr.", "Alkaid",
  "Sargas", "Menkalinan", "Peacock", "Alhena", "Avior",
  "Murzim", "Alphard", "Polaris", "Algol", "Suhail",
  "Alcyone", "Andromeda", "Zeta Retic.", "Galactic C.", "Great Attr.",

  "1st Cusp", "4th Cusp", "7th Cusp", "10th Cusp"};         // Extra
CONST char *szObjDisp[objMax];
CONST StrLook rgObjName[] = {{"Node", oNod}, {"Nod:", oNod},
  {"Rahu", oNod}, {"Ketu", oSou},
  {"M.C.", oMC}, {"I.C.", oNad},
  {"1st", oAsc}, {"4th", oNad}, {"7th", oDes}, {"10th", oMC},
  {"Vulcanus", oVlk},
  {"Star", starLo}, {"Orion", oOri}, {"Pleiades", oPle}, {"M31", oAnd},
  {"Milky Way", oGal}, {"", -1}};

CONST char *szSystem[cSystem] = {
  "Placidus", "Koch", "Equal", "Campanus", "Meridian", "Regiomontanus",
  "Porphyry", "Morinus", "Topocentric", "Alcabitius", "Krusinski",
  "Equal (MC)", "Pullen (S.Ratio)", "Pullen (S.Delta)", "Whole", "Vedic",
  "Sripati", "Horizon", "APC", "Carter P.Equat.", "Sunshine", "Savard-A",
  "Null",
  "Whole (MC)", "Vedic (MC)",
  "Equal (Balanced)", "Whole (Balanced)", "Vedic (Balanced)",
  "Equal (EP)", "Whole (EP)", "Vedic (EP)",
  "Equal (Vertex)", "Whole (Vertex)", "Vedic (Vertex)",
  "Porphyry (EP)", "Porphyry (Vertex)", "Pullen (SR, EP)",
  "Pullen (SR, Vertex)", "Pullen (SD, EP)", "Pullen (SD, Vertex)"};
CONST StrLook rgSystem[] = {{"E-Asc", hsEqual}, {"E-MC", hsEqualMC},
  {"P-SR", hsSineRatio}, {"P-SD", hsSineDelta},
  {"Ratio", hsSineRatio}, {"Delta", hsSineDelta},
  {"S-Ratio", hsSineRatio}, {"S-Delta", hsSineDelta},
  {"Albategnius", hsSavardA}, {"Albategnus", hsSavardA},
  {"W-Asc", hsWhole}, {"V-Asc", hsVedic},
  {"W-MC", hsWholeMC}, {"V-MC", hsVedicMC}, {"E-Bal", hsEqualBalanced},
  {"W-Bal", hsWholeBalanced}, {"V-Bal", hsVedicBalanced},
  {"E-EP", hsEqualEP}, {"W-EP", hsWholeEP}, {"V-EP", hsVedicEP},
  {"E-Ver", hsEqualVertex}, {"W-Ver", hsWholeVertex}, {"V-Ver", hsVedicVertex},
  {"P-EP", hsPorphyryEP}, {"P-Ver", hsPorphyryVtx},
  {"SR-EP", hsSineRatioEP}, {"SR-Ver", hsSineRatioVtx},
  {"SD-EP", hsSineDeltaEP}, {"SD-Ver", hsSineDeltaVtx}, {"", -1}};

CONST char *szAspectName[cAspect2+1] = {"",
  "Conjunct", "Opposite", "Square", "Trine", "Sextile",
  "Inconjunct", "SemiSextile", "SemiSquare", "SesquiQuadrate",
  "Quintile", "BiQuintile",
  "SemiQuintile", "Septile", "Novile",
  "BiNovile", "BiSeptile", "TriSeptile", "QuatroNovile",
  "TreDecile",
  "Undecile", "BiUndecile", "TriUndecile", "QuatroUndecile", "QuintUndecile",
  "Parallel", "ContraParallel"};
CONST StrLook rgAspectName[] =
  {{"Quincunx", aInc}, {"Octile", aSSq}, {"", -1}};
CONST char *szAspectDisp[cAspect2+1];

CONST char *szAspectAbbrev[cAspect2+1] = {"",
  "Con", "Opp", "Squ", "Tri", "Sex",
  "Inc", "SSx", "SSq", "Ses", "Qui", "BQn",
  "SQn", "Sep", "Nov", "BNv", "BSp", "TSp", "QNv",
  "TDc", "Un1", "Un2", "Un3", "Un4", "Un5",
  "Par", "CPr"};
CONST char *szAspectAbbrevDisp[cAspect2+1];

CONST char *szAspectGlyph[cAspect2+1] = {"",
  "Circle with extending line", "Two circles joined by line",
  "Quadrilateral", "Triangle", "Six pointed asterisk",
  "'K' rotated right", "'K' rotated left", "Acute angle",
  "Square with extending lines", "Letter 'Q'", "'+' over '-'",
  "'-' over '+'", "Number '7'", "Number '9'", "'9' under Roman 'II'",
  "'7' under Roman 'II'", "'7' under Roman 'III'", "'9' under Roman 'IV'",
  "'10' under Roman 'III'", "Number '11'", "'11' under Roman 'II'",
  "'11' under Roman 'III'", "'11' under Roman 'IV'", "'11' under Roman 'V'",
  "Parallel lines", "Crossed parallel lines"};
CONST char *szAspectGlyphDisp[cAspect2+1];

CONST char *szAspectConfig[cAspConfig] = {
  "Stellium-3", "Grand Trine", "T-Square", "Yod", "Grand Cross", "Cradle",
  "Rectangle", "Stellium-4"};
CONST int rgAspConfig[cAspConfig] = {
  aCon, aTri, aOpp, aInc, aSqu, aSex, aQui, aSSq};

CONST char *szElem[cElem] = {"Fire", "Earth", "Air", "Water"};
CONST char *szMode[3] = {"Cardinal", "Fixed", "Mutable"};

CONST char *szMonth[cSign+1] = {"",
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December"};

CONST char *szDay[cWeek] = {"Sunday", "Monday", "Tuesday", "Wednesday",
  "Thursday", "Friday", "Saturday"};

CONST char *szZon[cZone] = {
  "HST", "HT", "H", "CAT", "AHS", "HDT", "AHD", "YST", "YT", "Y", "YDT",
  "PST", "PT", "P", "PDT", "PWT", "MST", "MT", "M", "MDT", "MWT",
  "CST", "CT", "C", "CDT", "CWT", "EST", "ET", "E", "EDT", "EWT",
  "AST", "AT", "A", "ADT", "AWT", "BST", "BT", "B", "BDT", "WAT",
  "GMT", "GT", "G", "UTC", "UT", "U", "WET", "CET", "EET", "UZ3", "UZ4",
  "IST", "IT", "I", "UZ5", "NST", "SST", "CCT", "JST", "JT", "J",
  "SAS", "GST", "UZ1", "NZT", "ZT", "Z", "IDL", "LMT", "LT", "L", "LAT"};

CONST real rZon[cZone] = {
  10.0, 10.0, 10.0, 10.0, 10.0, 9.0, 9.0, 9.0, 9.0, 9.0,
  8.0, 8.0, 8.0, 8.0, 7.0, 7.0, 7.0, 7.0, 7.0, 6.0,
  6.0, 6.0, 6.0, 6.0, 5.0, 5.0, 5.0, 5.0, 5.0, 4.0,
  4.0, 4.0, 4.0, 4.0, 3.0, 3.0, 3.0, 3.0, 3.0, 2.0,
  1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1.0, -2.0,
  -4.0, -5.0, -5.5, -5.5, -5.5, -6.0, -6.5, -7.0, -8.0, -9.0,
  -9.0, -9.0, -9.5, -10.0, -11.0, -12.0, -12.0, -12.0, -12.0, zonLMT,
  zonLMT, zonLMT, zonLAT};

CONST char *rgszDir[4] = {"North", "East", "South", "West"};
CONST int dxOff[4] = { 0,-1, 0, 1};
CONST int dyOff[4] = {-1, 0, 1, 0};

CONST char *szSuffix[cSign+1] = {"",
  "st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "th", "th"};

CONST char *szEphem[cmMax] = {
  "Swiss Ephemeris 2.10.03", "Moshier Formulas 2.10.03",
  "JPL Ephemeris 2.10.03", "Placalc Ephemeris", "Matrix Formulas",
  "JPL Horizons Web Query", "None"};

CONST StrLookR rgZodiacOffset[] = {{"Fagan-Bradley", 0.0},
  {"Lahiri", 0.883208}, {"Deluce", -3.075453}, {"Raman", 2.329509},
  {"Usha-Shasi", 4.682759}, {"Krishnamurti", 0.98006},
  {"Djwhal Khul", -3.619379}, {"Yukteshwar", 2.261497},
  {"J.N. Bhasin", 1.978163}, {"Galactic Center", -2.105736}, {"", 0.0}};

CONST char *szNakshatra[cNakshat+1] = {"",
  "Ashvini", "Bharani", "Krittika", "Rohini", "Mrigashirsha", "Ardra",
  "Punarvasu", "Pushya", "Ashlesha", "Magha", "PPhalguni", "UPhalguni",
  "Hasta", "Chitra", "Swati", "Vishakha", "Anuradha", "Jyeshtha",
  "Mula", "PAshadha", "UAshadha", "Sravana", "Dhanishta", "Shatabhisha",
  "PBhadrapada", "UBhadrapada", "Revati"};

CONST char *rgszDecan[ddMax] = {"None", "Decan Ruler", "Decan Sign",
  "Chaldean Decan", "Egyptian Term", "Ptolemaic Term", "Navamsa",
  "12th Harmonic", "Dwad", "Nakshatra", "Constellation"};

CONST char *szEclipse[etMax] =
  {"No", "Penumbral", "Total Penumbral", "Partial", "Annular", "Total"};
CONST char rgchEclipse[etMax+1] = "9ptPAT";

CONST char *szAppSep[6] = {"neg", "pos", "app", "sep", "wax", "wan"};
CONST char rgchAppSep[6+1] = "-+asxn";

real rAspAngle[cAspect+1] = {0,
  0.0, 180.0, 90.0, 120.0, 60.0, 150.0, 30.0, 45.0, 135.0, 72.0, 144.0,
  36.0, rDegMax/7.0, 40.0, 80.0, rDegMax*2.0/7.0, rDegMax*3.0/7.0, 160.0,
  108.0, rDegMax/11.0, rDegMax*2.0/11.0, rDegMax*3.0/11.0, rDegMax*4.0/11.0,
  rDegMax*5.0/11.0};

real rAspOrb[cAspect+1] = {0,
  7.0, 7.0, 7.0, 7.0, 6.0, 3.0, 3.0, 3.0, 3.0, 2.0, 2.0,
  1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
  0.5, 0.5, 0.5, 0.5, 0.5, 0.5};

real rObjOrb[oNorm+2] = {360.0,
  360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0,
  360.0, 360.0, 360.0, 360.0, 360.0, 2.0, 2.0, 360.0, 360.0, 2.0,
  360.0, 360.0, 360.0, 360.0, 360.0, 360.0,
  360.0, 360.0, 360.0, 360.0, 360.0, 360.0,
  360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0,
  360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0, 360.0,
  2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
  2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
  2.0, 2.0, 2.0, 2.0, 2.0,
  2.0};

real rObjAdd[oNorm+2] = {0.0,
  1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0,
  0.0};

int ruler1[oNorm+1] = {sSag,
  sLeo, sCan, sGem, sLib, sAri, sSag, sCap, sAqu, sPis, sSco,
  sSag, sVir, sAqu, sLib, sSco, sAqu, sLeo, sSco, sPis, sLib, sAri,
  sAri, sTau, sGem, sCan, sLeo, sVir, sLib, sSco, sSag, sCap, sAqu, sPis,
  sVir, sLib, sSco, sLeo, sCap, sSag, sVir, sAri, sSag,
  sVir, sGem, sLib, sCan, sLeo, sAri, sTau, sGem, sCap,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int ruler2[oNorm+1] = {0,
  0, 0, sVir, sTau, sSco, sPis, sAqu, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int exalt[oNorm+1] = {sTau,
  sAri, sTau, sVir, sPis, sCap, sCan, sLib, sSco, sCan, sAqu,
  sPis, sTau, sCap, sLeo, sVir, sGem, sSag, sPis, sSag, sPis, sCap,
  sCap, sPis, sVir, sTau, sAri, sVir, sPis, sAqu, sCan, sLib, sSco, sCan,
  sCap, sGem, sVir, sAri, sSag, sAqu, sSco, sLeo, sPis,
  sLib, sAri, sGem, sVir, sCap, sSco, sLib, sPis, sAqu,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};

// This array is the reverse of the ruler arrays.
// Here, given a sign, return what planet rules it.
int rules[cSign+1] = {-1,
  oMar, oVen, oMer, oMoo, oSun, oMer, oVen, oPlu, oJup, oSat, oUra, oNep};
int rules2[cSign+1] = {-1,
  -1, -1, -1, -1, -1, -1, -1, oMar, -1, -1, oSat, oJup};

// Esoteric astrology tables
int rgObjRay[oNorm+1] = {3,
  2, 4, 4, 5, 6, 2, 3, 7, 6, 1,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  1, 4, 2, 3, 1, 2, 3, 4, 5, 7, 5, 6,
  1, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 3, 2, 1, 4, 7, 6, 5,    // 3214765: Seven circuit Labyrinth sequence!
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int rgSignRay[cSign+1] = {0,
  17, 4, 2, 37, 15, 26, 3, 4, 456, 137, 5, 26};
int rgSignRay2[cSign+1][cRay+1];
int rgObjEso1[oNorm+1] = {sSag,
  sLeo, sVir, sAri, sGem, sSco, sAqu, sCap, sLib, sCan, sPis,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  sAri, sTau, sGem, sCan, sLeo, sVir, sLib, sSco, sSag, sCap, sAqu, sPis,
  sTau, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int rgObjEso2[oNorm+1] = {0,
  0, 0, 0, 0, 0, 0, 0, 0, sLeo, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  sVir, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int rgObjHie1[oNorm+1] = {sGem,
  sLeo, sAqu, sSco, sCap, sSag, sVir, sLib, sAri, sCan, sPis,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  sAri, sTau, sGem, sCan, sLeo, sVir, sLib, sSco, sSag, sCap, sAqu, sPis,
  sTau, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int rgObjHie2[oNorm+1] = {0,
  0, 0, 0, 0, 0, 0, 0, sLeo, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  sAqu, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int rgSignEso1[cSign+1] = {-1,
  oMer, oVul, oVen, oNep, oSun, oMoo, oUra, oMar, oEar, oSat, oJup, oPlu};
int rgSignEso2[cSign+1] = {-1,
  -1, -1, -1, -1, oNep, -1, -1, -1, -1, -1, -1, -1};
int rgSignHie1[cSign+1] = {-1,
  oUra, oVul, oEar, oNep, oSun, oJup, oSat, oMer, oMar, oVen, oMoo, oPlu};
int rgSignHie2[cSign+1] = {-1,
  -1, -1, -1, -1, oUra, -1, -1, -1, -1, -1, oVul, -1};
int kRayA[cRay+2] = {kBlack,
  kRed, kIndigo, kForest, kYellow, kAmber, kRose, kViolet, kWhite};
CONST char *szRayName[cRay+1] = {"",
  "Will & Power", "Love & Wisdom", "Active Creative Intelligence",
  "Harmony Through Conflict", "Concrete Science", "Idealism & Devotion",
  "Order & Ceremonial Magic"};
CONST char *szRayWill[cRay+1] = {"",
  "Initiate", "Unify", "Evolve", "Harmonize", "Act", "Cause", "Express"};

// Colors
CONST char *szColor[cColor2+5] = {"Black",
  "Maroon", "DkGreen", "Maize", "DkBlue", "Purple", "DkCyan", "LtGray",
  "Gray", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White",
  "DkGray", "Orange", "Pink", "Brown",
  "Indigo", "Forest", "Amber", "Rose", "Sky", "Violet",
  "Element", "Ray", "Star", "Planet", "Auto"};
int kMainA[9] = {kBlack, kWhite, kLtGray, kDkGray,
  kMaroon, kDkGreen, kDkCyan, kDkBlue, kMagenta};
int kRainbowA[cRainbow+1] = {kWhite,
  kRed, kOrange, kYellow, kGreen, kCyan, kBlue, kPurple};
int kElemA[cElem] = {kRed, kYellow, kGreen, kBlue};
int kAspA[cAspect+1] = {kWhite,
  kYellow, kBlue, kRed, kGreen, kCyan,
  kMagenta, kMagenta, kOrange, kOrange, kDkCyan, kDkCyan,
  kDkCyan, kMaroon, kPurple, kPurple, kMaroon, kMaroon, kPurple,
  kDkCyan, kDkGreen, kDkGreen, kDkGreen, kDkGreen, kDkGreen};
int kObjU[oNorm+2] = {kYellow,
  kElement, kElement, kElement, kElement, kElement,
    kElement, kElement, kElement, kElement, kElement,
  kMagenta, kMagenta, kMagenta, kMagenta, kMagenta,
  kDkCyan, kDkCyan, kDkCyan, kDkCyan, kDkCyan, kDkCyan,
  kElement, kElement, kElement, kElement, kElement, kElement,
    kElement, kElement, kElement, kElement, kElement, kElement,
  kPurple,
    kPurple, kPurple, kPurple, kPurple, kPurple, kPurple, kPurple, kPurple,
  kMagenta, kMagenta, kPurple, kPurple, kPurple, kPurple, kPurple, kPurple,
    kPurple,
  kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet,
    kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet,
    kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet,
    kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet, kPlanet,
  kStar};
#ifndef GRAPH
// Copy of rgbbmpDef in xdata.c for non-graphics compiles.
CONST KV rgbbmp[cColor2] = {
  0x000000, 0x00007f, 0x007f00, 0x007f7f, // Main colors
  0x7f0000, 0x7f007f, 0x7f7f00, 0xbfbfbf,
  0x7f7f7f, 0x0000ff, 0x00ff00, 0x00ffff,
  0xff0000, 0xff00ff, 0xffff00, 0xffffff,
  0x3f3f3f, 0x007fff, 0x7f7fff, 0x003f7f, // Extra colors
  0xff3f3f, 0x008000, 0x00a5ff, 0xdf3eff, 0xff3a00, 0xcc0099}; // Ray colors
#endif

// Influence information used by ChartInfluence() follows. The influence of a
// planet in its ruling or exalting sign or house is tacked onto the last two
// positions of the object and house influence array, respectively.

// The inherent strength of each planet
real rObjInf[oNorm1+6] = {30,
  30, 25, 10, 10, 10, 10, 10, 10, 10, 10,
  5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
  20, 10, 10, 10, 10, 10, 10, 10, 10, 15, 10, 10,
  4, 3, 3, 3, 3, 3, 3, 3, 3,
  3, 3, 3, 3, 3, 3, 3, 3, 3,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  2,
  20, 10, 10, 10, 10};

// The inherent strength of each house
real rHouseInf[cSign+6]  = {0,
  20, 0, 0, 10, 0, 0, 5, 0, 0, 15, 0, 0,
  15, 5, 5, 5, 5};

// The inherent strength of each aspect
real rAspInf[cAspect+1] = {0.0,
  1.0, 0.8, 0.8, 0.6, 0.6, 0.4, 0.4, 0.2, 0.2,
  0.2, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,
  0.05, 0.05, 0.05, 0.05, 0.05, 0.05};

// The inherent strength of each planet when transiting
real rTransitInf[oNorm1+1] = {10,
  10, 4, 8, 9, 20, 30, 35, 40, 45, 50,
  30, 15, 15, 15, 15, 30, 30, 1, 1, 1, 1,
  1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
  6, 50, 50, 50, 50, 50, 50, 50, 50,
  15, 30, 50, 50, 50, 50, 50, 50, 50,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
  60};

// Informational astronomical data for planets
CONST real rObjDist[oNorm+1] = {rEarthDist, 0.0, 0.3844,
  57.91, 108.2, 227.94, 778.33, 1426.98, 2870.99, 4497.07, 5913.52,
  13.670*rEarthDist, 2.767*rEarthDist, 2.770*rEarthDist, 2.669*rEarthDist,
  2.361*rEarthDist, 0.3844, 0.3844, 0.3844,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  // Uranians
  0.13744*rEarthDist, 40.99837*rEarthDist, 50.66744*rEarthDist,
  59.21436*rEarthDist, 64.81690*rEarthDist, 70.29949*rEarthDist,
  73.62765*rEarthDist, 77.25568*rEarthDist, 83.66907*rEarthDist,
  // Dwarfs
  3.142*rEarthDist, 20.376*rEarthDist, 67.864*rEarthDist,
  43.182*rEarthDist, 45.431*rEarthDist, 67.474*rEarthDist,
  43.695*rEarthDist, 484.548*rEarthDist, 30.281*rEarthDist,
  // Moons
  0.0093772, 0.0234632, 1.0700428, 1.883, 0.421769, 0.671079,
  1.22187, 0.52707, 3.56084, 0.37742, 0.29467, 0.23804, 0.18554, 1.500933,
  0.4358, 0.5826, 0.266, 0.1912, 0.1298, 0.35476, 0.117647, 5.5134,
  0.017536, 0.064738, 0.048694, 0.057783, 0.042656,
  778.33, 1426.98, 2870.99, 4497.07, 5913.52};  // Units: M-km
CONST real rObjYear[oNorm+1] = {1.0, 0.0, 27.32166/rDayInYear,
  0.2408467, 0.61519726, 1.8808476, 11.862615,
  29.447498, 84.016846, 164.79132, 247.92065,
  50.71, 4.60, 4.62, 4.36, 3.63,
  -6792.45/rDayInYear, -6792.45/rDayInYear, 3396.225/rDayInYear,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  // Uranians
  18.58/rDayInYear, 94923.63/rDayInYear, 129906.79/rDayInYear,
  163537.13/rDayInYear, 186804.87/rDayInYear, 210470.60/rDayInYear,
  225232.03/rDayInYear, 241643.79/rDayInYear, 271464.37/rDayInYear,
  // Dwarfs
  5.57, 91.98, 559.07, 283.77, 306.22, 554.25, 288.84, 10666.28, 245.19,
  // Moons
  0.32/rDayInYear, 1.25/rDayInYear, 7.16/rDayInYear, 16.69/rDayInYear,
  1.77/rDayInYear, 3.55/rDayInYear, 15.95/rDayInYear, 4.52/rDayInYear,
  79.32/rDayInYear, 2.74/rDayInYear, 1.89/rDayInYear, 1.37/rDayInYear,
  0.94/rDayInYear, 21.28/rDayInYear, 8.71/rDayInYear, 13.46/rDayInYear,
  4.14/rDayInYear, 2.52/rDayInYear, 1.41/rDayInYear, -5.88/rDayInYear,
  1.12/rDayInYear, 360.11/rDayInYear, 6.39/rDayInYear, 38.2/rDayInYear,
  24.85/rDayInYear, 32.17/rDayInYear, 20.16/rDayInYear,
  11.862615, 29.447498, 84.016846, 164.79132, 247.92065};  // Units: years
real rObjDiam[oNorm+1] = {12742.0168, 1392000.0, 3475.0,
  4878.8, 12103.6, 6779.0, 139822.0, 116464.0, 50724.0, 49244.0, 2376.6,
  271.37, 939.4, 545.0, 246.596, 525.4, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  // Dwarfs
  407.12, 290.0, 2326.0, 1560.0, 1454.0, 1230.0, 1121.0, 1060.0, 910.0,
  // Moons
  11.0*2.0, 6.0*2.0, 2634.0*2.0, 2403.0*2.0, 1821.0*2.0, 1565.0*2.0,
  2575.0*2.0, 764.0*2.0, 734.0*2.0, 562.0*2.0,
  536.0*2.0, 252.0*2.0, 199.0*2.0, 133.0*2.0,
  789.0*2.0, 761.0*2.0, 585.0*2.0, 579.0*2.0, 236.0*2.0,
  1353.0*2.0, 209.0*2.0, 170.0*2.0,
  605.0*2.0, 39.0*2.0, 38.0*2.0, 13.0*2.0, 11.0*2.0,
  139822.0, 116464.0, 50724.0, 49244.0, 2376.6};  // Units: km
CONST real rObjDay[oNorm+1] = {24.0, 30.0*24.0, 27.322*24.0,
  58.65*24.0, 243.01*24.0, 24.6229, 9.841, 10.233, 17.9, 19.2, 6.3872*24.0,
  5.918, 9.074170, 7.8132, 7.210, 5.34212766, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  // Dwarfs
  13.828, 9.980, 25.9, 3.9154, 22.8266, 22.40, 8.840, 10.273, 13.188,
  // Moons
  0.319*24.0, 1.263*24.0, 7.155*24.0, 16.689*24.0, 1.769*24.0, 3.552*24.0,
  15.945*24.0, 4.518*24.0, 79.33*24.0, 2.737*24.0,
  1.888*24.0, 1.370*24.0, 0.942*24.0, 0.0,
  8.706*24.0, 13.463*24.0, 4.144*24.0, 2.520*24.0, 1.413*24.0,
  5.877*24.0, 1.122*24.0, 360.13619,
  6.38723*24.0, 0.0, 0.0, 0.0, 0.0,
  9.841, 10.233, 17.9, 19.2, 6.3872*24.0};  // Units: hr
CONST real rObjMass[oPlu+1] = {1.0, 322946.0, 0.0123,
  0.0553, 0.8149, 0.1074, 317.938, 95.181, 14.531, 17.135, 0.0022};
CONST real rObjAxis[oPlu+1] = {23.5, 0.0, 6.7,
  2.0, 2.7, 25.19, 3.12, 26.73, 82.14, 29.6, 57.54};
CONST int cSatellite[oPlu+1] = {1, 9, 0,
  0, 0, 2, 4, 8, 5, 3, 5};
CONST int nMooMap[6][8] = {  // Map JPL code number to Astrolog object index
  { 0,  1, -1, -1, -1, -1, -1, -1},  // Mars
  { 4,  5,  2,  3, -1, -1, -1, -1},  // Jupiter
  {12, 11, 10,  9,  7,  6, 13,  8},  // Saturn
  {17, 16, 14, 15, 18, -1, -1, -1},  // Uranus
  {19, 21, -1, -1, -1, -1, -1, 20},  // Neptune
  {22, 24, 23, 25, 26, -1, -1, -1}}; // Pluto
CONST int rgobjHasMoons[cHasMoons] =
  {oEar, oMar, oJup, oSat, oUra, oNep, oPlu, oEri, oHau, oQua, oOrc};

#ifdef ARABIC
CONST AI ai[cPart] = {
  {"    02 01F ", "Fortune"},
  {"    01 02F ", "Spirit"},
  {"    06 S F ", "Victory"},
  {"    F  05F ", "Valor & Bravery"},
  {"    05 03Fh", "Mind & Administrators"},
  {"   h02r02Fh", "Property & Goods"},
  {"    06 07 h", "Siblings"},
  {"   j03 01Fh", "Death of Siblings"},
  {"    06 07Fh", "Death of Parents"},
  {"    07h02Fh", "Grandparents"},
  {"    06 03Fh", "Real Estate"},
  {"    07 06Fh", "Children & Life"},
  {"   R02 02 h", "Expected Birth"},
  {"    05 03 h", "Disease & Defects (1)"},
  {"    05 07 h", "Disease & Defects (2)"},
  {"   R07 07 h", "Captivity"},
  {"    02 03 h", "Servants"},
  {"   h07 04 h", "Partners"},
  {"   h08 02 h", "Death"},
  {"    05 07Fh", "Sickness & Murder"},
  {"    03 07Fh", "Danger, Violence & Debt"},
  {"   h09r09 h", "Journeys"},
  {"   105 07Fh", "Travel by Water"},
  {"    03 02Fh", "Faith, Trust & Belief"},
  {"    02 07Fh", "Deep Reflection"},
  {"    01 07Fh", "Understanding & Wisdom"},
  {"    06 01Fh", "Fame & Recognition"},
  {"    02 05Fh", "Rulers & Disassociation"},
  {"    07 01Fh", "Father, Fate & Karma"}, // Combust
  {"    F  07Fh", "Sudden Advancement"},
  {"    01 07 h", "Celebrity of Rank"},
  {"    07 05Fh", "Surgery & Accident"},
  {"    04 03Fh", "Merchants & Their Work"},
  {"    F  S Fh", "Merchandise (Exchange)"}, // Moon
  {"    02 04Fh", "Mother"},
  {"    S  F Fh", "Glory & Constancy"},
  {"    01 F Fh", "Honorable Acquaintances"},
  {"    06 F Fh", "Success"},
  {"    04 F Fh", "Worldliness"},
  {"    03 02 h", "Acquaintances"},
  {"    03 S  h", "Violence"},
  {"    01 03Fh", "Liberty of Person"},
  {"    04 06Fh", "Praise & Acceptance"},
  {"   h12r12 h", "Enmity"},
  {"    F  S  h", "Bad Luck"},
  {"    05 F F ", "Debilitated Bodies"},
  {"    02D  F ", "Boldness & Violence"},
  {"    S  03F ", "Trickery & Deceit"},
  {"   h03 05  ", "Necessities"},
  {"    03 F   ", "Realization of Needs"},
  {"    01 05F ", "Retribution"},
  {"    06 02  ", "Children (Male)"},
  {"    04 02  ", "Children (Female)"},
  {"    05 04  ", "Play & Variety"}, // Change
  {"    07 03 h", "Stability"},
  {"   h05 06Fh", "Speculation"},
  {"    03 04Fh", "Art"},
  {"   h05r05 h", "Sexual Attraction"},
  {"    10 04 h", "Sex Drive & Stimulation"},
  {"    05 01 h", "Passion"},
  {"    05 04 h", "Emotion & Affection"},
  {"   r08 07 h", "Most Perilous Year"},
  {"   h08 07 h", "Peril"},
  {"    09 08 h", "Occultism"},
  {"    03 01 h", "Commerce"},
  {"h09h03 04 h", "Marriage Contracts"},
  {"   h09r09 h", "Travel by Land"},
  {"    08H08 h", "Travel by Air"},
  {" 31 01 02Fh", "Destiny"},
  {" 31 02 01Fh", "Vocation & Status"},
  {"   019 01 h", "Honor, Nobility (Day)"},
  {"   033 02 h", "Honor, Nobility (Night)"},
  {"    10 01 h", "Organization"},
  {"    04h07 h", "Divorce"},
  {"    08 01 h", "Ostracism & Loss"},
  {"    02 08Fh", "Friends"},
  {"    07 01 h", "Tragedy & Brethren"},
  {"    02 10Fh", "Race (Consciousness)"},
  {"    02D02Fh", "Bondage & Slavery"},
  {"    F  09 h", "Imprisonment & Sorrow"},
  {"    04 08 h", "Perversion"},
  {"   h12 09 h", "Self-Undoing"},
  {"    09 01 h", "Treachery & Entrapment"},
  {"h12r12 09 h", "Bereavement"},
  {"    06h12 h", "Suicide (Yang)"},
  {"   h08 09 h", "Suicide (Yin)"},
  {"    06 09 h", "Depression"},
  {" 05 09 08 h", "Assassination (Yang)"},
  {"   r12 09 h", "Assassination (Yin)"},
  {"    09 06  ", "Cancer (Disease)"},
  {"    08 07  ", "Catastrophe"},
  {"    07 08  ", "Foolhardiness"},
  {"    03 05  ", "Release & Luck"},
  {"    06 03  ", "Benevolence & Assurance"},
  {"    03 06  ", "Hope & Sensitivity"},
  {"    03 07  ", "Aptness & Aloofness"},
  {"    08 09  ", "Charm & Personality"},
  {"    02 03F ", "Faith & Good Manners"},
  {"    01 03  ", "Temperament"},
  {"    04 03  ", "Security & Treasure"},
  {"    08 03  ", "Originality"},
  {"    03 08  ", "Eccentricity, Astrology"},
  {"    09 03  ", "Divination"},
  {"    03 09  ", "Intrusion"},
  {"    05 06  ", "Negotiation"},
  {"    06 05  ", "Discord & Controversy"},
  {"    05 08  ", "Coincidence"},
  {"    08 05  ", "Unpreparedness"},
  {"    05 09  ", "Popularity"},
  {"    09 05  ", "Misunderstanding"},
  {"    04 06  ", "Sentiment & Marriage"},
  {"    06 04  ", "Loneliness"},
  {"    04 07  ", "Success in Investment"},
  {"    07 04  ", "Frugality & Labor"},
  {"    08 04  ", "Wastefulness"},
  {"    04 09  ", "Vanity"},
  {"    09 04  ", "Corruptness"},
  {"    01 05  ", "Initiative"},
  {"    05 02F ", "Memory"},
  {"    04 01  ", "Love, Beauty & Peace"},
  {"    01 04  ", "Disinterest & Boredom"},
  {"    01 06  ", "Accomplishment"},
  {"    07 02F ", "Influence"},
  {"    06 01  ", "Increase & Impression"},
  {"    09 07  ", "Caution"},
  {"    07 09  ", "Timidity"},
  {"    08 06  ", "Entertainment"},
  {"    06 08  ", "Bequest"},
  {"    01 09  ", "Genius"},
  {"    02 09F ", "Revelation"},
  {"    09 02F ", "Delusion"},
  {"    08 02F ", "Misinterpretation"},
  {"    01 08  ", "Intellectuality"},
  {"    06 07 E", "Earth"},
  {"    04 02 E", "Water"},
  {"   r04 03 E", "Air & Wind"},
  {"    05 01 E", "Fire"},
  {"    07 05FE", "Clouds"},
  {"    04 02FE", "Rains"},
  {"    07 03FE", "Cold"},
  {"    06 01FC", "Wheat"},
  {"    06 02FC", "Barley & Meats"},
  {"    04 06FC", "Rice & Millet"},
  {"    07 06FC", "Corn"},
  {"    07 05FC", "Lentils, Iron, Pungents"},
  {"    05 07FC", "Beans & Onions"},
  {"    01 03FC", "Chick Peas"},
  {"    04 07FC", "Sesame & Grapes"},
  {"    03 04FC", "Sugar & Legumes"},
  {"    01 02FC", "Honey"},
  {"    02 05FC", "Oils"},
  {"    04 05FC", "Nuts & Flax"},
  {"    02 03FC", "Olives"},
  {"    05 07FC", "Apricots & Peaches"},
  {"    03 06FC", "Melons"},
  {"    05 02FC", "Salt"},
  {"    03 01FC", "Sweets"},
  {"    07 03FC", "Astrigents & Purgatives"},
  {"    04 03FC", "Silk & Cotton"},
  {"    05 07FC", "Purgatives (Bitter)"},
  {"    06 07FC", "Purgatives (Acid)"},
  {"    31D   H", "Secrets"},
  {"    02 03FH", "Information True/False"},
  {"    F D  FH", "Injury to Business"},
  {" 03 07 06 H", "Freedmen & Servants"},
  {" 02 07 06 H", "Employers"},
  {"   h07 04 H", "Marriage"},
  {"    06 01 H", "Time for Action/Success"},
  {"    07 01 H", "Time Occupied in Action"},
  {" 07 06 01 H", "Dismissal & Resignation"},
  {"    05 02 H", "Life/Death of Absentee"},
  {"    05 01 H", "Lost Animal (Light)"},
  {"    05 07 H", "Lost Animal (Dark)"},
  {"    03 05 H", "Lawsuit"},
  {"h08 05 02 H", "Decapitation"},
  {" 31 07 02 H", "Torture"},
  {" 02h04D   H", "Lost Objects"}
};
#endif // ARABIC


/*
******************************************************************************
** Constellation Tables.
******************************************************************************
*/

#ifdef CONSTEL
CONST char *szCnstlName[cCnstl+1] = {"",
  "Andromeda", "Antlia", "Apus", "Aquarius",
  "Aquila", "Ara", "Aries", "Auriga",
  "Bootes", "Caelum", "Camelopardalis", "Cancer",
  "Canes Venatici", "Canis Major", "Canis Minor", "Capricornus",
  "Carina", "Cassiopeia", "Centaurus", "Cepheus",
  "Cetus", "Chamaeleon", "Circinus", "Columba",
  "Coma Berenices", "Corona Australis", "Corona Borealis", "Corvus",
  "Crater", "Crux", "Cygnus", "Delphinus",
  "Dorado", "Draco", "Equuleus", "Eridanus",
  "Fornax", "Gemini", "Grus", "Hercules",
  "Horologium", "Hydra", "Hydrus", "Indus",
  "Lacerta", "Leo", "Leo Minor", "Lepus",
  "Libra", "Lupus", "Lynx", "Lyra",
  "Mensa", "Microscopium", "Monoceros", "Musca",
  "Norma", "Octans", "Ophiuchus", "Orion",
  "Pavo", "Pegasus", "Perseus", "Phoenix",
  "Pictor", "Pisces", "Piscis Austrinus", "Puppis",
  "Pyxis", "Reticulum", "Sagitta", "Sagittarius",
  "Scorpius", "Sculptor", "Scutum", "Serpens Caput/Cauda",
  "Sextans", "Taurus", "Telescopium", "Triangulum",
  "Triangulum Australe", "Tucana", "Ursa Major", "Ursa Minor",
  "Vela", "Virgo", "Volans", "Vulpecula"};

CONST char *szCnstlAbbrev[cCnstl+1] = {"",
  "And", "Ant", "Aps", "Aqu", "Aql", "Ara", "Ari", "Aur",
  "Boo", "Cae", "Cam", "Cnc", "CVn", "CMa", "CMi", "Cap",
  "Car", "Cas", "Cen", "Cep", "Cet", "Cha", "Cir", "Col",
  "Com", "CrA", "CrB", "Crv", "Crt", "Cru", "Cyg", "Del",
  "Dor", "Dra", "Equ", "Eri", "For", "Gem", "Gru", "Her",
  "Hor", "Hya", "Hyi", "Ind", "Lac", "Leo", "LMi", "Lep",
  "Lib", "Lup", "Lyn", "Lyr", "Men", "Mic", "Mon", "Mus",
  "Nor", "Oct", "Oph", "Ori", "Pav", "Peg", "Per", "Phe",
  "Pic", "Psc", "PsA", "Pup", "Pyx", "Ret", "Sge", "Sgr",
  "Sco", "Scl", "Sct", "Ser", "Sex", "Tau", "Tel", "Tri",
  "TrA", "Tuc", "UMa", "UMi", "Vel", "Vir", "Vol", "Vul"};

CONST char *szCnstlMeaning[cCnstl+1] = {"",
  "Chained Maiden", "Air Pump", "Bird of Paradise", "Water Bearer",
  "Eagle", "Altar", "Ram", "Charioteer",
  "Herdsman", "Chisel", "Giraffe", "Crab",
  "Hunting Dogs", "Great Dog", "Little Dog", "Sea Goat",
  "Keel", "Queen", "Centaur", "King",
  "Sea Monster", "Chameleon", "Drawing Compass", "Dove",
  " Berenice's Hair", "Southern Crown", "Northern Crown", "Crow",
  "Cup", "Southern Cross", "Swan", "Dolphin",
  "Dolphinfish", "Dragon", "Little Horse", "River",
  "Furnace", "Twins", "Crane", "Strongman",
  "Clock", "Sea Serpent", "Water Snake", "Indian",
  "Lizard", "Lion", "Little Lion", "Hare",
  "Scales", "Wolf", "Lynx", "Lyre",
  "Table Mountain", "Microscope", "Unicorn", "Fly",
  "Level", "Octant", "Serpent Bearer", "Hunter",
  "Peacock", "Winged Horse", "Hero", "Phoenix",
  "Painter", "Fishes", "Southern Fish", "Stern",
  "Compass", "Net", "Arrow", "Archer",
  "Scorpion", "Sculptor", "Shield", " Head/Tail of the Snake",
  "Sextant", "Bull", "Telescope", "Triangle",
  "Southern Triangle", "Toucan", "Great Bear", "Little Bear",
  "Sail", "Virgin", "Flying Fish", "Fox"};

CONST char *szCnstlGenitive[cCnstl+1] = {"",
  "", "", "2odis", "", "", "", "1tis", "",
  "2is", "", "", "2ri", "2um1orum", " is", " is", "",
  "", "", "", "", "", "tis", "", "",
  "", "", "", "", "is", "", "", "",
  "1us", "nis", "", "", "", "1orum", "1is", "2is",
  "", "", "", "", "", "nis", "nis0is", "2oris",
  "", "", "", "", "", "", "1tis", "",
  "", "1is", "", "is", "nis", "", "", "",
  "is", "2ium", "", "", "1dis", "", "", "",
  "", "is", "", "!1is", "1tis", "", "", "",
  "2i1is", "", " is", " is", "1orum", "1inis", "1tis", ""};

CONST int iCnstlZodiac[cSign+1] = {0,
  7, 78, 38, 12, 46, 86, 49, 73, 72, 16, 4, 66};
CONST real lonCnstlZodiac[cSign+2] = {0.0,
  ZDMS(sAri, 29,  2, 44), ZDMS(sTau, 23, 23, 20), ZDMS(sCan,  0,  0,  0),
  ZDMS(sCan, 27, 54, 38), ZDMS(sLeo, 18, 34,  4), ZDMS(sVir, 23, 27, 53),
  ZDMS(sSco,  8, 22, 30), ZDMS(sSag,  2,  5, 21), ZDMS(sSag,  7, 46, 49),
  ZDMS(sSag, 26, 19, 44), ZDMS(sCap, 29, 49, 33), ZDMS(sAqu, 26, 46, 45),
  ZDMS(sPis, 22, 26, 21)};
#endif // CONSTEL


#ifdef INTERPRET
/*
******************************************************************************
** Interpretation Tables.
******************************************************************************
*/

CONST char *szMindPartDef[objMax] = {"arena of practical life experience",
  "spirit, ego, image of self, and sense of aliveness",
  "emotional nature, moods, feelings, and caring tendencies",
  "thoughts, intellect, and communicative activity",
  "creativity, tendencies for affection and calmness, and relationship needs",
  "will, energy, activity, and aggressive, assertive tendencies",
  "enthusiastic, faithful, wise, expansive, spontaneous nature",
  "part of mind that is disciplined, respectful, and solitary",
  "individuality, desires for change, and tendency to go against social norms",
  "intuitive, spiritual, compassionate, psychic nature",
  "destiny, and capacity to transform the self and the outer world",
  "ability to help, heal, and teach others, and where one has much experience",
  "tendency to direct energy to instinctive, creative, reproductive goals",
  "tendency to direct energy away from emotional and into mental pursuits",
  "tendency to give away individual power for the benefit of a relationship",
  "capacity to direct creative energy into personal or devotional goals",
  "karmic goals, and best direction of evolutionary growth",
  "karmic past, and area of experience but little growth",
  "capacity to let go and accept their natural darker side",
  "place where opportunity and success can be found",
  "karmic fate and method of reception of energies",
  "generalized projected personality and outward appearance",
  "personality and outward appearance, as projected to the world",
  "", "", "", "", "", "", "", "",
  "view as seen in the eyes of others, reputation, and social standing",
  "", "",
  // Uranians
  "will to purify and forge both physically and spiritually",
  "group associations and matters relating to art",
  "dark, secretive, past, shameful side",
  "fiery, creative, leadership tendencies",
  "lofty, extraordinary parts",
  "progressive, abundant energies",
  "intense, focused nature",
  "greatly forceful energies",
  "idealistic, honorable side",
  // Dwarfs
  "tendency toward purification and hygiene",
  "ability to change quickly, and deal with instability and the unexpected",
  "relation to energies of discord, strife, and scheming for advantage",
  "relation to energies of birth, sacrifice, and giving of oneself",
  "relation to energies of manifestation, will, and direction",
  "relation to energies of destruction, shifting, and unifying",
  "relation to energies of new creation, group activity, and laws",
  "relation to energies of victimization, trauma, and caretaking",
  "relation to energies of ripe karma, review, and necessary endings",
  // Moons
  "assertive part of Mars",
  "active part of Mars",
  "abundance part of Jupiter",
  "wisdom part of Jupiter",
  "creative part of Jupiter",
  "lively part of Jupiter",
  "past and karmic part of Saturn",
  "family ties part of Saturn",
  "limitation part of Saturn",
  "respect part of Saturn",
  "solitude and self-reliance part of Saturn",
  "manifestation part of Saturn",
  "discipline part of Saturn",
  "timing part of Saturn",
  "individuality part of Uranus",
  "driving change part of Uranus",
  "challenge of expression part of Uranus",
  "inspirational part of Uranus",
  "idealism part of Uranus",
  "psychological depths part of Neptune",
  "fluidity and illusion part of Neptune",
  "compassion and unity part of Neptune",
  "guidance to transformation part of Pluto",
  "struggle for transformation part of Pluto",
  "darkness and shadow side part of Pluto",
  "resistance to transformation part of Pluto",
  "essence of transformation part of Pluto",
  "enthusiastic, faithful, wise, expansive, spontaneous nature",
  "part of mind that is disciplined, respectful, and solitary",
  "individuality, desires for change, and tendency to go against social norms",
  "intuitive, spiritual, compassionate, psychic nature",
  "destiny, and capacity to transform the self and the outer world",
  // Stars
  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""};
CONST char *szMindPart[objMax];

CONST char *szDescDef[cSign+1] = {"",
  "forceful, energetic, direct, courageous",
  "practical, often skeptical and stubborn",
  "inquisitive, witty, perceptive, adaptable",
  "introspective, emotional, protective",
  "proud, gregarious, dramatic, dignified",
  "analytical, critical, modest, helpful",
  "affectionate, tolerant, often indecisive, appreciates beauty",
  "penetrating, suspicious, introspective",
  "jovial, open minded, loves freedom",
  "industrious, practical, disciplined",
  "progressive, erratic, revolutionary, idealistic, humanitarian, inventive",
  "imaginative, other worldly, impressionable"};
CONST char *szDesc[cSign+1];

CONST char *szDesireDef[cSign+1] = {"",
  "seeks adventure and challenge",
  "loves serenity and inner peace",
  "seeks out information",
  "wants inner and outer security",
  "desires self expression",
  "works toward perfection",
  "seeks balance, relationship, and calmness",
  "desires to transform and remove outer masks",
  "seeks meaning and new experience",
  "works for solitude and personal integrity",
  "desires individuality",
  "seeks transcendence of self"};
CONST char *szDesire[cSign+1];

CONST char *szLifeAreaDef[cSign+1] = {"",
  "establishment of personal identity",
  "self image, self worth, and material security",
  "communicating to and receiving from the environment",
  "imagination, fantasies, inner feelings, and domestic life",
  "finding joy, pleasure, and creative expression",
  "work and feeling talented and useful",
  "personal relationships and intimacy",
  "sex, death, the occult, and other hard to grasp topics",
  "changes, exploration, and the breaking of routine",
  "career, social stature, and destiny",
  "the future, life goals, and association with friends and groups",
  "things that disrupt or cause disassociation with the personality"};
CONST char *szLifeArea[cSign+1];

CONST char *szInteractDef[cAspect+1] = {"",
  "is %sconnected and fused together with",
  "%sopposes and creates tension with",
  "is %sin conflict with",
  "is %sin harmony with",
  "has %sopportunity for growth, exchange, and harmony in relation with",
  "is %sdifferent from",
  "%sgets new perspectives in relation with",
  "%screates internal friction with",
  "%screates internal agitation with",
  "%screatively relates externally with",
  "%screatively relates internally with",
  "", "", "", "", "", "", "", "", "", "", "", "", ""};
CONST char *szInteract[cAspect+1];

CONST char *szThereforeDef[cAspect+1] = {"",
  "Both parts are prominent in their psyche", "Balance is needed",
  "Adaptation is required by both sides", "", "",
  "They can often relate in a discordant way", "", "", "", "", "",
  "", "", "", "", "", "", ""};
CONST char *szTherefore[cAspect+1];

// Modifier array makes the interpretation stronger for narrower orbs.

CONST char *szModify[3][cAspect] =
  {{"always ", "always ", "irreconcilably ", "always ", "much ",
  "completely ", "often ", "often ", "often ", "often ", "often ",
  "", "", "", "", "", "", "", "", "", "", "", "", ""},
  {"", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
  "", "", "", "", "", ""},
  {"somewhat ", "somewhat ", "somewhat ", "somewhat ", "some ", "somewhat ",
  "sometimes ", "sometimes ", "sometimes ", "sometimes ", "sometimes ",
  "", "", "", "", "", "", "", "", "", "", "", "", ""}};

// Meanings of the Sabian Symbols for each of the 360 degrees.

CONST char *szSabian[nDegMax] = {
"A woman just risen from the sea; a seal is embracing her", // 0-1 Ari
"A comedian reveals human nature", // 1-2 Ari
"The cameo profile of a man, suggesting the shape of his country", // 2-3 Ari
"Two lovers strolling on a secluded walk", // 3-4 Ari
"A triangle with wings", // 4-5 Ari
"A square, with one of its sides brightly illumined", // 5-6 Ari
"A man succeeds in expressing himself simultaneously in two realms", // 6-7 Ari
"A large woman's hat with streamers blown by an east wind", // 7-8 Ari
"A crystal gazer", // 8-9 Ari
"A teacher gives new symbolic forms to traditional images", // 9-10 Ari
"The ruler of a nation", // 10-11 Ari
"A triangularly shaped flight of wild geese", // 11-12 Ari
"An unexploded bomb reveals an unsuccessful social protest", // 12-13 Ari
"A serpent coiling near a man and a woman", // 13-14 Ari
"An Indian weaving a ceremonial blanket", // 14-15 Ari
"Nature spirits are seen at work in the light of sunset", // 15-16 Ari
"Two dignified spinsters sitting in silence", // 16-17 Ari
"An empty hammock stretched between two trees", // 17-18 Ari
"The \"magic carpet\" of East Asian imagery", // 18-19 Ari
"A young girl feeding birds in winter", // 19-20 Ari
"A pugilist enters the ring", // 20-21 Ari
"The gate to the garden of all fulfilled desires", // 21-22 Ari
"A pregnant woman in light summer dress", // 22-23 Ari
"Blown inward by the wind, the curtains of an open window take the shape of a\
 cornucopia", // 23-24 Ari
"The possibility for man to gain experience at two levels of being",
// 24-25 Ari
"A man possessed of more gifts than he can hold", // 25-26 Ari
"Through imagination a lost opportunity is regained", // 26-27 Ari
"A large audience confronts the performer who disappointed its expectations",
// 27-28 Ari
"The music of the spheres", // 28-29 Ari
"A duck pond and its brood", // 29-30 Ari
"A clear mountain stream", // 0-1 Tau
"An electrical storm", // 1-2 Tau
"Natural steps lead to a lawn of clover in bloom", // 2-3 Tau
"The pot of gold at the end of the rainbow", // 3-4 Tau
"A widow at an open grave", // 4-5 Tau
"Cantilever bridge across a deep gorge", // 5-6 Tau
"The woman of Samaria at the ancestral well", // 6-7 Tau
"A sleigh on land uncovered by snow", // 7-8 Tau
"A fully decorated Christmas tree", // 8-9 Tau
"A Red Cross nurse", // 9-10 Tau
"A woman watering flowers in her garden.", // 10-11 Tau
"A young couple window shopping", // 11-12 Tau
"A porter carrying heavy baggage", // 12-13 Tau
"On the beach, children play while shellfish grope at the edge of the water",
// 13-14 Tau
"Head covered with a rakish silk hat, muffled against the cold, a man braves \
a storm", // 14-15 Tau
"An old teacher fails to interest his pupils in traditional knowledge",
// 15-16 Tau
"A symbolical battle between \"swords\" and \"torches\"", // 16-17 Tau
"A woman airing an old bag through the open window of her room", // 17-18 Tau
"A new continent rising out of the ocean", // 18-19 Tau
"Wisps of winglike clouds streaming across the sky", // 19-20 Tau
"A finger pointing to a line in an open book", // 20-21 Tau
"White dove flying over troubled waters", // 21-22 Tau
"A jewelry shop filled with valuable gems", // 22-23 Tau
"An Indian warrior riding fiercely, human scalps hanging from his belt",
// 23-24 Tau
"A vast public park", // 24-25 Tau
"A Spanish gallant serenades his beloved", // 25-26 Tau
"An old Indian woman selling the artifacts of her tribe to passerby",
// 26-27 Tau
"A woman, past her \"change of life\", experiences a new love", // 27-28 Tau
"Two cobblers working at a table", // 28-29 Tau
"A peacock parading on the terrace of an old castle", // 29-30 Tau
"A glass-bottomed boat reveals undersea wonders", // 0-1 Gem
"Santa Claus furtively filling stockings hanging in front of fireplace",
// 1-2 Gem
"The garden of the tuileries in Paris", // 2-3 Gem
"Holly and mistletoe reawaken old memories of Christmas", // 3-4 Gem
"A revolutionary magazine asking for action", // 4-5 Gem
"Workmen drilling for oil", // 5-6 Gem
"A well with bucket and rope under the shade of majestic trees", // 6-7 Gem
"Aroused strikers surround a factory", // 7-8 Gem
"A quiver filled with arrows", // 8-9 Gem
"An airplane performing a nose dive", // 9-10 Gem
"Newly opened lands offer the pioneer new opportunities for experience",
// 10-11 Gem
"A black girl fights for her independence in the city", // 11-12 Gem
"A famous pianist giving a concert performance", // 12-13 Gem
"Bridging physical space and social distinctions, two men communicate telepat\
hically", // 13-14 Gem
"Two Dutch children talking to each other, exchanging their knowledge",
// 14-15 Gem
"A woman activist in an emotional speech dramatizing her cause", // 15-16 Gem
"The head of a robust youth changes into that of a mature thinker",
// 16-17 Gem
"Two Chinese men converse in their native tongue in an American city",
// 17-18 Gem
"A large archaic volume reveals a traditional wisdom", // 18-19 Gem
"A modern cafeteria displays an abundance of food, products of various region\
s", // 19-20 Gem
"A tumultuous labor demonstration", // 20-21 Gem
"Dancing couples in a harvest festival", // 21-22 Gem
"Three fledglings in a nest high in a tree", // 22-23 Gem
"Children skating over a frozen village pond", // 23-24 Gem
"A gardener trimming large palm trees", // 24-25 Gem
"Frost-covered trees against winter skies", // 25-26 Gem
"A Romani emerging from the forest wherein her tribe is encamped", // 26-27 Gem
"Through bankruptcy, society gives to an overburdened individual the opportun\
ity to begin again", // 27-28 Gem
"The first mockingbird of spring", // 28-29 Gem
"A parade of bathing beauties before large beach crowds", // 29-30 Gem
"On a ship the sailors lower an old flag and raise a new one", // 0-1 Can
"A man on a magic carpet hovers over a large area of land", // 1-2 Can
"A man bundled in fur leads a shaggy deer", // 2-3 Can
"A cat arguing with a mouse", // 3-4 Can
"At a railroad crossing, an automobile is wrecked by a train", // 4-5 Can
"Game birds feathering their nests", // 5-6 Can
"Two nature spirits dancing under the moonlight", // 6-7 Can
"A group of rabbits dressed in human clothes walk as if on parade", // 7-8 Can
"A small girl bends over a pond trying to catch a fish", // 8-9 Can
"A large diamond in the first stages of the cutting process", // 9-10 Can
"A clown caricaturing well-known personalities", // 10-11 Can
"A Chinese woman nursing a baby whose aura reveals him to be the reincarnatio\
n of a great teacher", // 11-12 Can
"A hand with a prominent thumb is held out for study", // 12-13 Can
"A very old man facing a vast dark space to the Northeast", // 13-14 Can
"In a sumptuous dining hall guests relax after partaking of a huge banquet",
// 14-15 Can
"A man studying a mandala in front of him, with the help of a very ancient bo\
ok", // 15-16 Can
"The unfoldment of multilevel potentialities issuing from an original germ",
// 16-17 Can
"A hen scratching the ground to find nourishment for her progeny", // 17-18 Can
"A priest performing a marriage ceremony", // 18-19 Can
"Venetian gondoliers giving a serenade", // 19-20 Can
"A famous singer is proving her virtuosity during an operatic performance",
// 20-21 Can
"A young woman awaiting a sailboat", // 21-22 Can
"The meeting of a literary society", // 22-23 Can
"A woman and two men castaways on a small island of the South Seas",
// 23-24 Can
"A willful man is overshadowed by a descent of superior power", // 24-25 Can
"Guests are reading in the library of a luxurious home", // 25-26 Can
"A violent storm in a canyon filled with expensive homes", // 26-27 Can
"An Indian girl introduces her white lover to her assembled tribe",
// 27-28 Can
"A Greek muse weighing newborn twins in golden scales", // 28-29 Can
"A daughter of the American revolution", // 29-30 Can
"Blood rushes to a man's head as his vital energies are mobilized under the s\
pur of ambition", // 0-1 Leo
"An epidemic of mumps", // 1-2 Leo
"A middle-aged woman, her long hair flowing over her shoulders and in a youth\
ful garment", // 2-3 Leo
"A formally dressed elderly man stands near trophies he brought back from a h\
unting expedition", // 3-4 Leo
"Rock formations tower over a deep canyon", // 4-5 Leo
"A conservative, old-fashioned lady is confronted by a \"hippie\" girl",
// 5-6 Leo
"The constellations of stars shine brilliantly in the night sky", // 6-7 Leo
"A communist activist spreading his revolutionary ideals", // 7-8 Leo
"Glass blowers shape beautiful vases with their controlled breathing",
// 8-9 Leo
"Early morning dew sparkles as sunlight floods the field", // 9-10 Leo
"Children play on a swing hanging from the branches of a huge oak tree",
// 10-11 Leo
"An evening party of adults on a lawn illumined by fancy lanterns",
// 11-12 Leo
"An old sea captain rocking himself on the porch of his cottage", // 12-13 Leo
"A human soul seeking opportunities for outward manifestation", // 13-14 Leo
"A pageant, with its spectacular floats, moves along a street crowded with ch\
eering people", // 14-15 Leo
"The storm ended, all nature rejoices in brilliant sunshine", // 15-16 Leo
"A volunteer church choir singing religious hymns", // 16-17 Leo
"A chemist conducts an experiment for his students", // 17-18 Leo
"A houseboat party", // 18-19 Leo
"Zuni Indians perform a ritual to the sun", // 19-20 Leo
"Intoxicated chickens dizzily flap their wings trying to fly", // 20-21 Leo
"A carrier pigeon fulfilling its mission", // 21-22 Leo
"In a circus the bareback rider displays her dangerous skill", // 22-23 Leo
"Totally concentrated upon inner spiritual attainment, a man is sitting in a \
state of complete neglect of bodily appearance and cleanliness", // 23-24 Leo
"A large camel is seen crossing a vast and forbidding desert", // 24-25 Leo
"After the heavy storm, a rainbow", // 25-26 Leo
"The luminescence of dawn in the eastern sky", // 26-27 Leo
"Many little birds on a limb of a big tree", // 27-28 Leo
"A mermaid emerges from the ocean waves ready for rebirth in human form",
// 28-29 Leo
"An unsealed letter", // 29-30 Leo
"In a portrait, the significant features of a man's head are artistically emp\
hasized", // 0-1 Vir
"A large white cross dominates the landscape", // 1-2 Vir
"Two guardian angels", // 2-3 Vir
"Black and white children play together happily", // 3-4 Vir
"A man becoming aware of nature spirits and normally unseen spiritual agencie\
s", // 4-5 Vir
"A merry-go-round", // 5-6 Vir
"A harem", // 6-7 Vir
"A five-year-old child takes a first dancing lesson", // 7-8 Vir
"An expressionist painter at work", // 8-9 Vir
"Two heads looking out and beyond the shadows", // 9-10 Vir
"In her baby a mother sees her deep longing for a son answered", // 10-11 Vir
"After the wedding, the groom snatches the veil away from his bride",
// 11-12 Vir
"A powerful statesman overcomes a state of political hysteria", // 12-13 Vir
"An aristocratic family tree", // 13-14 Vir
"A fine lace handkerchief, heirloom from valorous ancestors", // 14-15 Vir
"In the zoo, children are brought face to face with an orangutan", // 15-16 Vir
"A volcanic eruption", // 16-17 Vir
"An Ouija board", // 17-18 Vir
"A swimming race", // 18-19 Vir
"A caravan of cars headed to the West coast", // 19-20 Vir
"A girls' basketball team", // 20-21 Vir
"A royal coat of arms enriched with precious stones", // 21-22 Vir
"A lion tamer displays his skill and character", // 22-23 Vir
"Mary and her little lamb", // 23-24 Vir
"A flag at half-mast in front of a public building", // 24-25 Vir
"A boy with a censer serves the priest near the altar", // 25-26 Vir
"A group of aristocratic ladies meet ceremonially at a court's function",
// 26-27 Vir
"A baldheaded man who has seized power", // 27-28 Vir
"A seeker after occult knowledge is reading an ancient scroll which illumines\
 his mind", // 28-29 Vir
"Totally intent upon completing an immediate task, a man is deaf to any allur\
ement", // 29-30 Vir
"In a collection of perfect specimens of many biological forms, a butterfly d\
isplays the beauty of its wings, its body impaled by a fine dart", // 0-1 Lib
"The transmutation of the fruits of past experiences into the seed-realizatio\
ns of the forever creative spirit", // 1-2 Lib
"The dawn of a new day reveals everything changed", // 2-3 Lib
"Around a campfire a group of young people sit in spiritual communion",
// 3-4 Lib
"A man revealing to his students the foundation of an inner knowledge upon wh\
ich a \"new world\" could be built", // 4-5 Lib
"A man watches his ideals taking a concrete form before his inner vision",
// 5-6 Lib
"A woman feeding chickens and protecting them from the hawks", // 6-7 Lib
"A blazing fireplace in a deserted home", // 7-8 Lib
"Three \"old masters\" hanging on the wall of a special room in an art galler\
y", // 8-9 Lib
"Having passed through narrow rapids, a canoe reaches calm waters", // 9-10 Lib
"A professor peering over his glasses at his students", // 10-11 Lib
"Miners are surfacing from a deep coal mine", // 11-12 Lib
"Children blowing soap bubbles", // 12-13 Lib
"In the heat of the noon hour a man takes a siesta", // 13-14 Lib
"Circular paths", // 14-15 Lib
"After a storm a boat landing stands in need of reconstruction", // 15-16 Lib
"A retired sea captain watches ships entering and leaving the harbor",
// 16-17 Lib
"Two men placed under arrest", // 17-18 Lib
"A gang of robbers in hiding", // 18-19 Lib
"A rabbi performing his duties", // 19-20 Lib
"A Sunday crowd enjoying the beach", // 20-21 Lib
"A child giving birds a drink at a fountain", // 21-22 Lib
"Chanticleer's voice heralds sunrise", // 22-23 Lib
"A butterfly with a third wing on its left side", // 23-24 Lib
"The sight of an Autumn leaf brings to a pilgrim the sudden revelation of the\
 mystery of life and death", // 24-25 Lib
"An eagle and a large white dove change into each other", // 25-26 Lib
"An airplane sails, high in the clear sky", // 26-27 Lib
"A man becoming aware of spiritual forces surrounding and assisting him",
// 27-28 Lib
"Mankind's vast and enduring effort to reach for knowledge transferable from \
generation to generation", // 28-29 Lib
"Three mounds of knowledge on a philosopher's head", // 29-30 Lib
"A crowded sightseeing bus on a city street", // 0-1 Sco
"A delicate bottle of perfume lies broken, releasing its fragrance", // 1-2 Sco
"A house-raising party in a small village enlists the neighbors' cooperation",
// 2-3 Sco
"A youth carries a lighted candle in a devotional ritual", // 3-4 Sco
"A massive rocky shore resists the pounding of the sea", // 4-5 Sco
"The gold rush tears men away from their native soil", // 5-6 Sco
"Deep-sea divers", // 6-7 Sco
"A calm lake bathed in moonlight", // 7-8 Sco
"A dentist at work", // 8-9 Sco
"A fellowship supper reunites old comrades", // 9-10 Sco
"A drowning man is being rescued", // 10-11 Sco
"An official embassy ball", // 11-12 Sco
"An inventor performs a laboratory experiment", // 12-13 Sco
"Telephone lineman at work installing new connections", // 13-14 Sco
"Children playing around five mounds of sand", // 14-15 Sco
"A girl's face breaking into a smile", // 15-16 Sco
"A woman, fecundated by her own spirit, is \"great with child\"", // 16-17 Sco
"A path through woods brilliant with multicolored splendor", // 17-18 Sco
"A parrot repeats the conversation he has overheard", // 18-19 Sco
"A woman draws away two dark curtains closing the entrance to a sacred pathwa\
y", // 19-20 Sco
"Obeying his conscience, a soldier resists orders", // 20-21 Sco
"Hunters shooting wild ducks", // 21-22 Sco
"A rabbit metamorphoses into a nature sprit", // 22-23 Sco
"After having heard an inspired individual deliver his \"Sermon on the Mount,\
\" crowds are returning home", // 23-24 Sco
"An X-ray photograph", // 24-25 Sco
"American Indians making camp after moving into a new territory", // 25-26 Sco
"A military band marches noisily on through the city streets", // 26-27 Sco
"The king of the fairies approaching his domain", // 27-28 Sco
"An Indian woman pleading to the chief for the lives of her children",
// 28-29 Sco
"Children in Halloween costumes indulge in various pranks", // 29-30 Sco
"Retired army veterans gather to reawaken old memories", // 0-1 Sag
"White-capped waves display the power of wind over sea", // 1-2 Sag
"Two men playing chess", // 2-3 Sag
"A little child learning to walk with the encouragement of his parents",
// 3-4 Sag
"An old owl sits alone on the branch of a large tree", // 4-5 Sag
"A game of cricket", // 5-6 Sag
"Cupid knocks at the door of a human heart", // 6-7 Sag
"Within the depths of the Earth new elements are being formed", // 7-8 Sag
"A mother leads her small child step by step up a steep stairway", // 8-9 Sag
"A theatrical representation of a golden-haired goddess of opportunity",
// 9-10 Sag
"In the left section of an archaic temple, a lamp burns in a container shaped\
 like a human body", // 10-11 Sag
"A flag turns into an eagle; the eagle into a chanticleer saluting the dawn",
// 11-12 Sag
"A widow's past is brought to light", // 12-13 Sag
"The Great Pyramid and the Sphinx", // 13-14 Sag
"The ground hog looking for its shadow on Ground Hog Day", // 14-15 Sag
"Sea gulls fly around a ship in expectation of food", // 15-16 Sag
"An Easter sunrise service draws a large crowd", // 16-17 Sag
"Children playing on the beach, their heads protected by sunbonnets",
// 17-18 Sag
"Pelicans menaced by the behavior and refuse of men seek safer areas for brin\
ging up their young", // 18-19 Sag
"In an old-fashioned Northern village men cut the ice of a frozen pond for us\
e during the Summer", // 19-20 Sag
"A child and a dog wearing borrowed eyeglasses", // 20-21 Sag
"A Chinese laundry", // 21-22 Sag
"A group of immigrants as they fulfill the requirements of entrance into the \
new country", // 22-23 Sag
"A bluebird perched on the gate of a cottage", // 23-24 Sag
"A chubby boy on a hobby-horse", // 24-25 Sag
"A flag bearer in a battle", // 25-26 Sag
"A sculptor at his work", // 26-27 Sag
"An old bridge over a beautiful stream is still in constant use", // 27-28 Sag
"A fat boy mowing the lawn of his house on an elegant suburban street",
// 28-29 Sag
"The Pope blessing the faithful", // 29-30 Sag
"An Indian chief claims power from the assembled tribe", // 0-1 Cap
"Three rose windows in a Gothic church, one damaged by war", // 1-2 Cap
"A human soul, in its eagerness for new experiences, seeks embodiment",
// 2-3 Cap
"A group of people outfitting a large canoe at the start of a journey by wate\
r", // 3-4 Cap
"Indians on the warpath. While some men row a well-filled canoe, others in it\
 perform a war dance", // 4-5 Cap
"Ten logs lie under an archway leading to darker woods", // 5-6 Cap
"A veiled prophet speaks, seized by the power of a god", // 6-7 Cap
"In a sunlit home domesticated birds sing joyously", // 7-8 Cap
"An Angel carrying a harp", // 8-9 Cap
"An albatross feeding from the hand of a sailor", // 9-10 Cap
"A large group of pheasant on a private estate", // 10-11 Cap
"An illustrated lecture on natural science reveals little-known aspects of li\
fe", // 11-12 Cap
"A fire worshipper meditates on the ultimate realities of existence",
// 12-13 Cap
"An ancient bas-relief carved in granite remains a witness to a long-forgotte\
n culture", // 13-14 Cap
"In a hospital, the children's ward is filled with toys", // 14-15 Cap
"School grounds filled with boys and girls in gymnasium suits", // 15-16 Cap
"A repressed woman finds a psychological release in nudism", // 16-17 Cap
"The Union Jack flag files from a British warship", // 17-18 Cap
"A five-year-old child carrying a bag filled with groceries", // 18-19 Cap
"A hidden choir is singing during a religious service", // 19-20 Cap
"A relay race", // 20-21 Cap
"By accepting defeat gracefully, a general reveals nobility of character",
// 21-22 Cap
"A soldier receiving two awards for bravery in combat", // 22-23 Cap
"A woman entering a convent", // 23-24 Cap
"A store filled with precious East Asian rugs", // 24-25 Cap
"A nature sprit dancing in the iridescent mist of a waterfall", // 25-26 Cap
"Pilgrims climbing the steep steps leading to a mountain shrine", // 26-27 Cap
"A large aviary", // 27-28 Cap
"A woman reading tea leaves", // 28-29 Cap
"A secret meeting of men responsible for executive decisions in world affairs",
// 29-30 Cap
"An old adobe mission in California", // 0-1 Aqu
"An unexpected thunderstorm", // 1-2 Aqu
"A deserter from the navy", // 2-3 Aqu
"A Hindu yogi demonstrates his healing powers", // 3-4 Aqu
"A council of ancestors is seen implementing the efforts of a young leader",
// 4-5 Aqu
"A masked figure performs ritualistic acts in a mystery play", // 5-6 Aqu
"A child is seen being born out of an egg", // 6-7 Aqu
"Beautifully gowned wax figures on display", // 7-8 Aqu
"A flag is seen turning into an eagle", // 8-9 Aqu
"A man who had for a time become the embodiment of a popular ideal is made to\
 realize that as a person he is not this ideal", // 9-10 Aqu
"During a silent hour, a man receives a new inspiration which may change his \
life", // 10-11 Aqu
"On a vast staircase stand people of different types, graduated upward",
// 11-12 Aqu
"A barometer", // 12-13 Aqu
"A train entering a tunnel", // 13-14 Aqu
"Two lovebirds sitting on a fence and singing happily", // 14-15 Aqu
"A big businessman at his desk", // 15-16 Aqu
"A watchdog stands guard, protecting his master and his possessions",
// 16-17 Aqu
"A man's secret motives are being publicly unmasked", // 17-18 Aqu
"A forest fire is being subdued by the use of water, chemicals and sheer musc\
ular energy", // 18-19 Aqu
"A large white dove bearing a message", // 19-20 Aqu
"A disappointed and disillusioned woman courageously faces a seemingly empty \
life", // 20-21 Aqu
"A rug is placed on the floor of a nursery to allow children to play in comfo\
rt and warmth", // 21-22 Aqu
"A big bear sitting down and waving all its paws", // 22-23 Aqu
"A man, having overcome his passions, teaches deep wisdom in terms of his exp\
erience", // 23-24 Aqu
"A butterfly with the right wing more perfectly formed", // 24-25 Aqu
"A garage man testing a car's battery with a hydrometer", // 25-26 Aqu
"An ancient pottery bowl filled with fresh violets", // 26-27 Aqu
"A tree felled and sawed to ensure a supply of wood for the winter",
// 27-28 Aqu
"A butterfly emerging from a chrysalis", // 28-29 Aqu
"Deeply rooted in the past of a very ancient culture, a spiritual brotherhood\
 in which many individual minds are merged into the glowing light of a unanim\
ous consciousness is revealed to one who has emerged successfully from his me\
tamorphosis", // 29-30 Aqu
"In a crowded marketplace farmers and middlemen display a great variety of pr\
oducts", // 0-1 Pis
"A squirrel hiding from hunters", // 1-2 Pis
"Petrified tree trunks lie broken on desert sand", // 2-3 Pis
"Heavy car traffic on a narrow isthmus linking two seashore resorts",
// 3-4 Pis
"A church bazaar", // 4-5 Pis
"A parade of army officers in full dress", // 5-6 Pis
"Illumined by a shaft of light, a large cross lies on rocks surrounded by sea",
// 6-7 Pis
"A girl blowing a bugle", // 7-8 Pis
"A jockey spurs his horse, intent on outdistancing his rivals", // 8-9 Pis
"An aviator pursues his journey, flying through ground-obscuring clouds",
// 9-10 Pis
"Men traveling a narrow path, seeking illumination", // 10-11 Pis
"In the sanctuary of an occult brotherhood, newly initiated members are being\
 examined and their character tested", // 11-12 Pis
"An ancient sword, used in many battles, is displayed in a museum",
// 12-13 Pis
"A lady wrapped in a large stole of fox fur", // 13-14 Pis
"An officer instructing his men before a simulated assault under a barrage of\
 live shells", // 14-15 Pis
"In the quiet of his study a creative individual experiences a flow of inspir\
ation", // 15-16 Pis
"An Easter parade", // 16-17 Pis
"In a gigantic tent, villagers witness a spectacular performance", // 17-18 Pis
"A master instructing his disciple", // 18-19 Pis
"A table set for an evening meal", // 19-20 Pis
"Under the watchful and kind eye of a Chinese servant, a girl fondles a littl\
e white lamb", // 20-21 Pis
"A prophet carrying tablets of the new law is walking down the slopes of Moun\
t Sinai", // 21-22 Pis
"A \"materializing\" medium giving a seance", // 22-23 Pis
"On a small island surrounded by the vast expanse of the sea, people are seen\
 living in close interaction", // 23-24 Pis
"A religious organization succeeds in overcoming the corrupting influence of \
perverted practices and materialized ideals", // 24-25 Pis
"Watching the very thin Moon crescent appearing at sunset, different people r\
ealize that the time has come to go ahead with their different projects",
// 25-26 Pis
"The harvest Moon illumines a clear autumnal sky", // 26-27 Pis
"A fertile garden under the Full Moon reveals a variety of full-grown vegetab\
les", // 27-28 Pis
"Light breaking into many colors as it passes through a prism", // 28-29 Pis
"A majestic rock formation resembling a face is idealized by a boy who takes \
it as his ideal of greatness, and as he grows up, begins to look like it"
// 29-30 Pis
};
#endif // INTERPRET

/* data.cpp */
