function ACTCircle(mc, x, y, r, color, width, fill) {
if (width > 0) { mc.lineStyle(width, color, 100); } else { mc.lineStyle(); }
if (fill) { mc.beginFill(color, 100); }
mc.moveTo(x + r, y);
mc.curveTo(x + r * 1.0000000, y + r * 0.4142136, x + r * 0.7071068, y + r * 0.7071068);
mc.curveTo(x + r * 0.4142136, y + r * 1.0000000, x + r * 0.0000000, y + r * 1.0000000);
mc.curveTo(x + r * -0.4142136, y + r * 1.0000000, x + r * -0.7071068, y + r * 0.7071068);
mc.curveTo(x + r * -1.0000000, y + r * 0.4142136, x + r * -1.0000000, y + r * 0.0000000);
mc.curveTo(x + r * -1.0000000, y + r * -0.4142136, x + r * -0.7071068, y + r * -0.7071068);
mc.curveTo(x + r * -0.4142136, y + r * -1.0000000, x + r * -0.0000000, y + r * -1.0000000);
mc.curveTo(x + r * 0.4142136, y + r * -1.0000000, x + r * 0.7071068, y + r * -0.7071068);
mc.curveTo(x + r * 1.0000000, y + r * -0.4142136, x + r * 1.0000000, y + r * -0.0000000);
if (fill) { mc.endFill(); }
}
function ACTIcon0(mc, color, background) { mc.clear();
        ACTCircle(mc, 10, 5, 4, color, 0, true);
        DrawBox(mc, 3, 12, 14, 8, color, 100, 0, 0, 4);
     }
function ACTIcon1(mc, color, background) { mc.clear();
        DrawBox(mc, 1, 6, 19, 4, color, 100, 0, 0, 1);
        DrawBox(mc, 2, 11, 8, 11, color, 100, 0, 0, 0);
        DrawBox(mc, 12, 11, 7, 11, color, 100, 0, 0, 0);
        mc.lineStyle(1.6, color, 100); mc.moveTo(10, 6);
        mc.curveTo(0, 6, 5, 1); mc.curveTo(9, 0, 10, 6);
        mc.curveTo(12, 0, 17, 1); mc.curveTo(21, 6, 10, 6);
     }
function ACTIcon2(mc, color, background) { mc.clear();
        ACTCircle(mc, 11, 11, 9, color, 2.2, false);
        ACTCircle(mc, 7.5, 8, 1.1, color, 0, true);
        ACTCircle(mc, 14.5, 8, 1.1, color, 0, true);
        mc.lineStyle(1.8, color, 100); mc.moveTo(6, 13);
        mc.curveTo(11, 19, 16, 13);
     }
function ACTIcon3(mc, color, background) { mc.clear(); mc.lineStyle(); mc.beginFill(color, 100);
mc.moveTo(11, 1);
mc.lineTo(21, 6);
mc.lineTo(21, 17);
mc.lineTo(11, 23);
mc.lineTo(1, 17);
mc.lineTo(1, 6);
mc.lineTo(11, 1); mc.endFill();
        mc.lineStyle(1.5, background, 100); mc.moveTo(1,6); mc.lineTo(11,12);
        mc.lineTo(21,6); mc.moveTo(11,12); mc.lineTo(11,23);
        mc.moveTo(6,3.5); mc.lineTo(16,9);
     }
function ACTIcon4(mc, color, background) { mc.clear();
        ACTCircle(mc, 4, 6, 3, color, 0, true);
        ACTCircle(mc, 18, 6, 3, color, 0, true);
        DrawBox(mc, 0, 12, 8, 7, color, 100, 0, 0, 3);
        DrawBox(mc, 14, 12, 8, 7, color, 100, 0, 0, 3);
        ACTCircle(mc, 11, 5, 3.8, color, 0, true);
        DrawBox(mc, 5, 11, 12, 10, color, 100, background, 1, 4);
     }
function ACTIcon5(mc, color, background) { mc.clear(); mc.lineStyle(); mc.beginFill(color, 100);
mc.moveTo(1, 1);
mc.lineTo(5, 2);
mc.lineTo(18, 15);
mc.lineTo(16, 17);
mc.lineTo(3, 4);
mc.lineTo(1, 1); mc.endFill();mc.lineStyle(); mc.beginFill(color, 100);
mc.moveTo(20, 1);
mc.lineTo(16, 2);
mc.lineTo(3, 15);
mc.lineTo(5, 17);
mc.lineTo(18, 4);
mc.lineTo(20, 1); mc.endFill();
        mc.lineStyle(2.5, color, 100); mc.moveTo(13,18); mc.lineTo(18,13);
        mc.moveTo(3,13); mc.lineTo(8,18); mc.moveTo(16,17); mc.lineTo(20,21);
        mc.moveTo(5,17); mc.lineTo(1,21);
     }
function ACTIcon6(mc, color, background) { mc.clear();
        DrawBox(mc, 1, 6, 21, 15, color, 100, 0, 0, 2);
        DrawBox(mc, 6, 3, 9, 5, color, 100, 0, 0, 2);
        ACTCircle(mc, 11.5, 13.5, 4.7, background, 0, true);
        ACTCircle(mc, 11.5, 13.5, 2.8, color, 0, true);
        ACTCircle(mc, 19, 9, 1, background, 0, true);
     }
function ACTIcon7(mc, color, background) { mc.clear(); mc.lineStyle(); mc.beginFill(color, 100);
mc.moveTo(4, 3);
mc.lineTo(17, 3);
mc.lineTo(21, 12);
mc.lineTo(22, 14);
mc.lineTo(22, 20);
mc.lineTo(19, 20);
mc.lineTo(19, 22);
mc.lineTo(16, 22);
mc.lineTo(16, 20);
mc.lineTo(6, 20);
mc.lineTo(6, 22);
mc.lineTo(3, 22);
mc.lineTo(3, 20);
mc.lineTo(0, 20);
mc.lineTo(0, 14);
mc.lineTo(1, 12);
mc.lineTo(4, 3); mc.endFill();
        DrawBox(mc, 5, 5, 12, 6, background, 100, 0, 0, 2);
        ACTCircle(mc, 4, 15, 1.5, background, 0, true);
        ACTCircle(mc, 18, 15, 1.5, background, 0, true);
     }
function ACTIcon8(mc, color, background) { mc.clear();
        ACTCircle(mc, 11, 11, 10, color, 1.7, false);
        mc.lineStyle(1.3, color, 100); mc.moveTo(1,11); mc.lineTo(21,11);
        mc.moveTo(11,1); mc.curveTo(1,11,11,21);
        mc.moveTo(11,1); mc.curveTo(21,11,11,21);
     }
function ACTIcon9(mc, color, background) { mc.clear(); mc.lineStyle(); mc.beginFill(color, 100);
mc.moveTo(19.5, 11.0);
mc.lineTo(21.865, 12.721);
mc.lineTo(21.462, 14.399);
mc.lineTo(20.801, 15.994);
mc.lineTo(17.877, 15.996);
mc.lineTo(17.01, 17.01);
mc.lineTo(17.466, 19.899);
mc.lineTo(15.994, 20.801);
mc.lineTo(14.399, 21.462);
mc.lineTo(12.33, 19.395);
mc.lineTo(11.0, 19.5);
mc.lineTo(9.279, 21.865);
mc.lineTo(7.601, 21.462);
mc.lineTo(6.006, 20.801);
mc.lineTo(6.004, 17.877);
mc.lineTo(4.99, 17.01);
mc.lineTo(2.101, 17.466);
mc.lineTo(1.199, 15.994);
mc.lineTo(0.538, 14.399);
mc.lineTo(2.605, 12.33);
mc.lineTo(2.5, 11.0);
mc.lineTo(0.135, 9.279);
mc.lineTo(0.538, 7.601);
mc.lineTo(1.199, 6.006);
mc.lineTo(4.123, 6.004);
mc.lineTo(4.99, 4.99);
mc.lineTo(4.534, 2.101);
mc.lineTo(6.006, 1.199);
mc.lineTo(7.601, 0.538);
mc.lineTo(9.67, 2.605);
mc.lineTo(11.0, 2.5);
mc.lineTo(12.721, 0.135);
mc.lineTo(14.399, 0.538);
mc.lineTo(15.994, 1.199);
mc.lineTo(15.996, 4.123);
mc.lineTo(17.01, 4.99);
mc.lineTo(19.899, 4.534);
mc.lineTo(20.801, 6.006);
mc.lineTo(21.462, 7.601);
mc.lineTo(19.395, 9.67);
mc.lineTo(19.5, 11.0); mc.endFill();ACTCircle(mc, 11, 11, 4.5, background, 0, true); }
function ACTText(parent, name, depth, x, y, w, h, size, color, label) {
    var t = parent[name];
    if (t == undefined) { t = MkText(parent, name, depth, x, y, w, h, size, color, false); }
    RestyleText(t, size, color, w, h);
    SetText(t, label);
    t.hscroll = 0; t.actWait = 0; t.actOffset = 0; t.actDirection = 1;
    return t;
}
function ACTRootRow(i, label, selected) {
    var mc = _root.ACTPanel.rootRows["r" + i];
    mc.clear();
    var bg = _root.ACTRow;
    var color = _root.ACTTextColor;
    if (selected) { bg = _root.ACTSelectedFill; color = _root.ACTSelectedInk; }
    DrawBox(mc, 0, 0, 278, 30, bg, 100, 0, 0, 5);
    if (!selected && i > 0) { DrawBox(mc, 3, 30, 272, 0.7, _root.ACTBorder, 100, 0, 0, 0); }
    RestyleText(mc.label, 14, color);
    if (mc.label.text != label || mc.actSelected != selected) { ACTScrollReset(mc.label); }
    SetText(mc.label, label); mc.actSelected = selected;
    mc.arrow.clear(); mc.arrow.lineStyle(1.8, color, 100);
    mc.arrow.moveTo(0, 0); mc.arrow.lineTo(5, 5); mc.arrow.lineTo(0, 10);
if (i == 0) { ACTIcon0(mc.icon, color, bg); }
if (i == 1) { ACTIcon1(mc.icon, color, bg); }
if (i == 2) { ACTIcon2(mc.icon, color, bg); }
if (i == 3) { ACTIcon3(mc.icon, color, bg); }
if (i == 4) { ACTIcon4(mc.icon, color, bg); }
if (i == 5) { ACTIcon5(mc.icon, color, bg); }
if (i == 6) { ACTIcon6(mc.icon, color, bg); }
if (i == 7) { ACTIcon7(mc.icon, color, bg); }
if (i == 8) { ACTIcon8(mc.icon, color, bg); }
if (i == 9) { ACTIcon9(mc.icon, color, bg); }
if (i == 10) { ACTIcon9(mc.icon, color, bg); }

}
function ACTSubRow(i, name, value, selected) {
    var mc = _root.ACTPanel.subRows["r" + i];
    mc.clear();
    if (mc.actName != name || mc.actValue != value || mc.actSelected != selected) { ACTScrollReset(mc.label); ACTScrollReset(mc.value); }
    mc.actName = name; mc.actValue = value; mc.actSelected = selected;
    var bg = _root.ACTFill;
    var color = _root.ACTTextColor;
    var dim = _root.ACTDim;
    if (selected) { bg = _root.ACTSelectedFill; color = _root.ACTSelectedInk; dim = color; }
    DrawBox(mc, 0, 0, 276, 29, bg, 100, 0, 0, 4);
    if (!selected) { DrawBox(mc, 2, 29, 272, 0.7, _root.ACTBorder, 100, 0, 0, 0); }
    RestyleText(mc.label, 12, color); SetText(mc.label, name);
    RestyleText(mc.value, 11, dim); SetText(mc.value, value);
}
function ACTColors() {
    if (_root.ACTFill != undefined) { return; }
    _root.ACTFill = 1581870; _root.ACTRow = 1911350; _root.ACTBorder = 3425876;
    _root.ACTTextColor = 15988472; _root.ACTDim = 11451076;
    _root.ACTSelectedFill = 10471392; _root.ACTSelectedInk = 1187883;
}
function ACTChrome() {
    var p = _root.ACTPanel; p.clear();
    DrawBox(p, 0, 0, 300, 412, _root.ACTFill, 100, _root.ACTBorder, 1, 15);
    ACTText(p, "title", 1, 22, 12, 170, 35, 29, _root.ACTTextColor, "ACT");
    ACTText(p, "subtitle", 2, 22, 41, 200, 19, 12, _root.ACTDim, "Command Toolkit");
    DrawBox(p, 239, 19, 47, 27, _root.ACTFill, 100, _root.ACTBorder, 1, 8);
    ACTText(p, "version", 3, 247, 24, 36, 18, 12, _root.ACTDim, "v0.1");

}
function ACTInit() {
    ThemeInit(); ACTColors();
    if (_root.ACTPanel != undefined) { return; }
    var p = _root.createEmptyMovieClip("ACTPanel", 90);
    ACTChrome();
    var rr = p.createEmptyMovieClip("rootRows", 10);

    var row = rr.createEmptyMovieClip("r0", 1);
    row._x = 11; row._y = 63;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Player");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(0, "Player", false);

    var row = rr.createEmptyMovieClip("r1", 2);
    row._x = 11; row._y = 94;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Support & Rewards");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(1, "Support & Rewards", false);

    var row = rr.createEmptyMovieClip("r2", 3);
    row._x = 11; row._y = 125;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Fun");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(2, "Fun", false);

    var row = rr.createEmptyMovieClip("r3", 4);
    row._x = 11; row._y = 156;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Quick Spawn");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(3, "Quick Spawn", false);

    var row = rr.createEmptyMovieClip("r4", 5);
    row._x = 11; row._y = 187;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Troops");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(4, "Troops", false);

    var row = rr.createEmptyMovieClip("r5", 6);
    row._x = 11; row._y = 218;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "War Creator");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(5, "War Creator", false);

    var row = rr.createEmptyMovieClip("r6", 7);
    row._x = 11; row._y = 249;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Creator Camera");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(6, "Creator Camera", false);

    var row = rr.createEmptyMovieClip("r7", 8);
    row._x = 11; row._y = 280;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Vehicles");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(7, "Vehicles", false);

    var row = rr.createEmptyMovieClip("r8", 9);
    row._x = 11; row._y = 311;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "World");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(8, "World", false);

    var row = rr.createEmptyMovieClip("r9", 10);
    row._x = 11; row._y = 342;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Native Dev Menu");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(9, "Native Dev Menu", false);

    var row = rr.createEmptyMovieClip("r10", 11);
    row._x = 11; row._y = 373;
    ACTText(row, "label", 2, 46, 8, 211, 22, 14, _root.ACTTextColor, "Impostazioni");
    var icon = row.createEmptyMovieClip("icon", 1); icon._x = 13; icon._y = 7;
    var arrow = row.createEmptyMovieClip("arrow", 3); arrow._x = 266; arrow._y = 11;
    ACTRootRow(10, "Impostazioni", false);

    var sub = p.createEmptyMovieClip("subRows", 11);
    sub._x = 10; sub._y = 63;
    DrawBox(sub, 0, 0, 280, 339, _root.ACTFill, 100, 0, 0, 4);
    ACTText(sub, "title", 1, 12, 11, 250, 21, 14, _root.ACTTextColor, "");
    DrawBox(sub, 8, 33, 264, 0.7, _root.ACTBorder, 100, 0, 0, 0);

    var row = sub.createEmptyMovieClip("r0", 10);
    row._x = 2; row._y = 38;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(0, "", "", false);

    var row = sub.createEmptyMovieClip("r1", 11);
    row._x = 2; row._y = 68;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(1, "", "", false);

    var row = sub.createEmptyMovieClip("r2", 12);
    row._x = 2; row._y = 98;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(2, "", "", false);

    var row = sub.createEmptyMovieClip("r3", 13);
    row._x = 2; row._y = 128;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(3, "", "", false);

    var row = sub.createEmptyMovieClip("r4", 14);
    row._x = 2; row._y = 158;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(4, "", "", false);

    var row = sub.createEmptyMovieClip("r5", 15);
    row._x = 2; row._y = 188;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(5, "", "", false);

    var row = sub.createEmptyMovieClip("r6", 16);
    row._x = 2; row._y = 218;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(6, "", "", false);

    var row = sub.createEmptyMovieClip("r7", 17);
    row._x = 2; row._y = 248;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(7, "", "", false);

    var row = sub.createEmptyMovieClip("r8", 18);
    row._x = 2; row._y = 278;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(8, "", "", false);

    var row = sub.createEmptyMovieClip("r9", 19);
    row._x = 2; row._y = 308;
    ACTText(row, "label", 1, 10, 6, 190, 20, 12, _root.ACTTextColor, "");
    ACTText(row, "value", 2, 200, 6, 70, 20, 11, _root.ACTDim, "");
    ACTSubRow(9, "", "", false);

    rr._visible = true; sub._visible = false;
    _root.ACTSel = -1; _root.ACTSubSel = -1;
    p._visible = false;
}
function ACTLayout(pct) {
    ACTInit();
    if (pct <= 0) { pct = 100; }
    _root.ACTPanel._x = 22 * 100 / pct;
    _root.ACTPanel._y = 20 * 100 / pct;
    _root.ACTPanel._xscale = 6000 / pct;
    _root.ACTPanel._yscale = 6000 / pct;
}
function ACTVisible(on) { ACTInit(); _root.ACTPanel._visible = on; }
function ACTMode(rootMode) {
    ACTInit();
    _root.ACTPanel.rootRows._visible = rootMode;
    _root.ACTPanel.subRows._visible = !rootMode;
}
function ACTSelected(i) {
    ACTInit();
    if (i < 0 || i > 10 || i == _root.ACTSel) { return; }
if (_root.ACTSel == 0) { ACTRootRow(0, "Player", false); }
    if (i == 0) { ACTRootRow(0, "Player", true); }
if (_root.ACTSel == 1) { ACTRootRow(1, "Support & Rewards", false); }
    if (i == 1) { ACTRootRow(1, "Support & Rewards", true); }
if (_root.ACTSel == 2) { ACTRootRow(2, "Fun", false); }
    if (i == 2) { ACTRootRow(2, "Fun", true); }
if (_root.ACTSel == 3) { ACTRootRow(3, "Quick Spawn", false); }
    if (i == 3) { ACTRootRow(3, "Quick Spawn", true); }
if (_root.ACTSel == 4) { ACTRootRow(4, "Troops", false); }
    if (i == 4) { ACTRootRow(4, "Troops", true); }
if (_root.ACTSel == 5) { ACTRootRow(5, "War Creator", false); }
    if (i == 5) { ACTRootRow(5, "War Creator", true); }
if (_root.ACTSel == 6) { ACTRootRow(6, "Creator Camera", false); }
    if (i == 6) { ACTRootRow(6, "Creator Camera", true); }
if (_root.ACTSel == 7) { ACTRootRow(7, "Vehicles", false); }
    if (i == 7) { ACTRootRow(7, "Vehicles", true); }
if (_root.ACTSel == 8) { ACTRootRow(8, "World", false); }
    if (i == 8) { ACTRootRow(8, "World", true); }
if (_root.ACTSel == 9) { ACTRootRow(9, "Native Dev Menu", false); }
    if (i == 9) { ACTRootRow(9, "Native Dev Menu", true); }
if (_root.ACTSel == 10) { ACTRootRow(10, "Impostazioni", false); }
    if (i == 10) { ACTRootRow(10, "Impostazioni", true); }

    _root.ACTSel = i;
}
function ACTSubTitle(title) { ACTInit(); var t = _root.ACTPanel.subRows.title; if (t.text != title) { ACTScrollReset(t); } SetText(t, title); }
function ACTSubSet(i, name, value, selected) {
    ACTInit();
    if (i < 0 || i > 9) { return; }
    ACTSubRow(i, name, value, selected);
}
function ACTPalette(fill, row, border, text, dim, selected, ink) {
    ACTInit();
    _root.ACTFill = fill; _root.ACTRow = row; _root.ACTBorder = border;
    _root.ACTTextColor = text; _root.ACTDim = dim;
    _root.ACTSelectedFill = selected; _root.ACTSelectedInk = ink;
    ACTChrome();
    var sub = _root.ACTPanel.subRows; sub.clear();
    DrawBox(sub, 0, 0, 280, 339, fill, 100, 0, 0, 4);
    DrawBox(sub, 8, 33, 264, 0.7, border, 100, 0, 0, 0);
    RestyleText(sub.title, 14, text);
    ACTRootRow(0, "Player", _root.ACTSel == 0);
    ACTRootRow(1, "Support & Rewards", _root.ACTSel == 1);
    ACTRootRow(2, "Fun", _root.ACTSel == 2);
    ACTRootRow(3, "Quick Spawn", _root.ACTSel == 3);
    ACTRootRow(4, "Troops", _root.ACTSel == 4);
    ACTRootRow(5, "War Creator", _root.ACTSel == 5);
    ACTRootRow(6, "Creator Camera", _root.ACTSel == 6);
    ACTRootRow(7, "Vehicles", _root.ACTSel == 7);
    ACTRootRow(8, "World", _root.ACTSel == 8);
    ACTRootRow(9, "Native Dev Menu", _root.ACTSel == 9);
    ACTRootRow(10, "Impostazioni", _root.ACTSel == 10);
    var r = sub.r0; ACTSubRow(0, r.actName, r.actValue, r.actSelected);
    var r = sub.r1; ACTSubRow(1, r.actName, r.actValue, r.actSelected);
    var r = sub.r2; ACTSubRow(2, r.actName, r.actValue, r.actSelected);
    var r = sub.r3; ACTSubRow(3, r.actName, r.actValue, r.actSelected);
    var r = sub.r4; ACTSubRow(4, r.actName, r.actValue, r.actSelected);
    var r = sub.r5; ACTSubRow(5, r.actName, r.actValue, r.actSelected);
    var r = sub.r6; ACTSubRow(6, r.actName, r.actValue, r.actSelected);
    var r = sub.r7; ACTSubRow(7, r.actName, r.actValue, r.actSelected);
    var r = sub.r8; ACTSubRow(8, r.actName, r.actValue, r.actSelected);
    var r = sub.r9; ACTSubRow(9, r.actName, r.actValue, r.actSelected);
}
function ACTScrollReset(t) { t.hscroll = 0; t.actWait = 0; t.actOffset = 0; t.actDirection = 1; }
function ACTScrollText(t, dt) {
    var limit = t.maxhscroll;
    if (limit == undefined || limit <= 0) { return; }
    if (t.actWait == undefined) { ACTScrollReset(t); }
    if (t.actWait < 1.5) { t.actWait = t.actWait + dt; return; }
    t.actOffset = t.actOffset + t.actDirection * dt * 10;
    if (t.actOffset >= limit) { t.actOffset = limit; t.actDirection = -1; t.actWait = 0; }
    if (t.actOffset <= 0) { t.actOffset = 0; t.actDirection = 1; t.actWait = 0; }
    t.hscroll = Math.floor(t.actOffset);
}
function ACTScrollTick(dt) {
    if (_root.ACTPanel == undefined || !_root.ACTPanel._visible) { return; }
    var p = _root.ACTPanel;
    if (p.rootRows._visible) {
        var r = p.rootRows["r" + _root.ACTSel];
        if (r != undefined) { ACTScrollText(r.label, dt); }
    } else {
        ACTScrollText(p.subRows.title, dt);
        var r = p.subRows.r0; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r1; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r2; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r3; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r4; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r5; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r6; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r7; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r8; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }
        var r = p.subRows.r9; if (r.actSelected) { ACTScrollText(r.label, dt); ACTScrollText(r.value, dt); }

    }
}
function ACTCrosshair(on, scale, stageY) {
    var c = _root.ACTCameraCross;
    if (c == undefined) {
        c = _root.createEmptyMovieClip("ACTCameraCross", 95);
        c.lineStyle(1.1, 15988472, 100);
        c.moveTo(-6, 0); c.lineTo(-2, 0); c.moveTo(2, 0); c.lineTo(6, 0);
        c.moveTo(0, -6); c.lineTo(0, -2); c.moveTo(0, 2); c.lineTo(0, 6);
    }
    c._x = 426.5 * 100 / scale; c._y = stageY * 100 / scale;
    c._xscale = 10000 / scale; c._yscale = 10000 / scale;
    c._visible = on;
}
function ACTProbe() { fscommand("essui", "ACT_RUNTIME_READY"); }
