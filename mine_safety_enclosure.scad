// ==============================================================================
// 3D MODEL FOR AUTOCAD / TINKERCAD / 3D PRINTING
// PROJECT: IoT-Based Coal Mine Safety Monitoring & Real-Time Alerting System
// ENCLOSURE: blue protective EVA zip case (as on the real prototype)
//   - two rounded half-shells joined by a zipper band
//   - top half (lid): window for LCD 1602 in the middle,
//     round opening for MQ-135 on the left, window for DHT11 on the right
//   - right end: opening for the USB power cable
// OUTER SIZE: 170 mm (L) x 100 mm (W) x 77 mm (H)    WALL (EVA + fabric): 4 mm
// ==============================================================================
// Axes: X = length (left -> right), Y = depth (front = -Y), Z = up.
// Z = 0 is the middle of the zipper band.

$fn = 64;

// ---------- main dimensions (mm)
L        = 170;   // length
W        = 100;   // depth (front to back)
R_plan   = 32;    // corner radius seen from above
wall     = 4;     // EVA wall incl. fabric
zip_h    = 5;     // zipper band height
bot_h    = 40;    // bottom half height (below the zipper band)
bot_r    = 12;    // edge rounding of the bottom
top_h    = 32;    // top half (lid) height (above the zipper band)
top_r    = 22;    // edge rounding of the lid (dome)

// ---------- openings in the lid (all on the flat top)
lcd_win  = [76, 30];     // LCD 1602 window (module 80 x 36 is held under the fabric)
lcd_pos  = [4, 0];       // window centre (x, y)
mq_d     = 21;           // MQ-135 opening diameter (left of the screen)
mq_pos   = [-48.5, 0];   // (x, y)
dht_win  = [16, 20];     // DHT11 window (x size, y size) (right of the screen)
dht_pos  = [52.5, 0];    // (x, y)

// ---------- opening in the bottom half
usb_d    = 9;            // USB cable opening (right end)
usb_pos  = [10, -14];    // (y, z) on the right end

// ---------- display options
show_components = true;  // simplified electronics (preview only)
lid_open_angle  = 0;     // 0 = closed, e.g. 100 = opened on the back hinge
explode         = 0;     // extra gap between the halves (mm)

case_blue = [0.11, 0.33, 0.78];
zip_blue  = [0.07, 0.20, 0.52];

// ---------- helper solids
// corner profile: vertical wall h_wall, then a rounded edge of radius rf
module corner_profile(rp, h_wall, rf) {
    intersection() {
        square([rp, h_wall + rf]);
        hull() {
            square([rp, h_wall]);
            translate([rp - rf, h_wall]) circle(r = rf);
            square([rp - rf, h_wall + rf]);
        }
    }
}
// rounded "pillow" half-shell solid
module half_solid(l, w, rp, h_wall, rf) {
    hull() for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * (l/2 - rp), sy * (w/2 - rp), 0])
            rotate_extrude() corner_profile(rp, h_wall, rf);
}
// plan-view rounded rectangle prism
module plan_prism(l, w, rp, h) {
    hull() for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * (l/2 - rp), sy * (w/2 - rp), 0]) cylinder(r = rp, h = h);
}

// ---------- 1. BOTTOM HALF (open at the top)
module bottom_half() {
    color(case_blue) difference() {
        translate([0, 0, -zip_h/2]) mirror([0, 0, 1])
            half_solid(L, W, R_plan, bot_h - bot_r, bot_r);
        translate([0, 0, -zip_h/2 + 0.01]) mirror([0, 0, 1])
            half_solid(L - 2*wall, W - 2*wall, R_plan - wall, bot_h - bot_r, bot_r - wall);
        // USB cable opening (right end)
        translate([L/2 - wall - 3, usb_pos[0], usb_pos[1]]) rotate([0, 90, 0])
            cylinder(d = usb_d, h = wall + 8);
    }
}

// ---------- 2. ZIPPER BAND (ring between the halves)
module zipper_band() {
    color(zip_blue) translate([0, 0, -zip_h/2]) difference() {
        plan_prism(L + 1.5, W + 1.5, R_plan + 0.75, zip_h);
        translate([0, 0, -1]) plan_prism(L - 2*wall, W - 2*wall, R_plan - wall, zip_h + 2);
    }
    // zipper slider and pull tab (back right corner)
    color([0.75, 0.76, 0.78]) {
        translate([L/2 - R_plan - 6, W/2 + 0.2, -3]) cube([12, 3, 6]);
        translate([L/2 - R_plan - 2, W/2 + 3, -11]) cube([4, 1.2, 10]);
    }
}

// ---------- 3. TOP HALF / LID with LCD window and sensor openings
module top_half() {
    color(case_blue) difference() {
        translate([0, 0, zip_h/2]) half_solid(L, W, R_plan, top_h - top_r, top_r);
        translate([0, 0, zip_h/2 - 0.01])
            half_solid(L - 2*wall, W - 2*wall, R_plan - wall, top_h - top_r, top_r - wall);
        // LCD 1602 window
        translate([lcd_pos[0] - lcd_win[0]/2, lcd_pos[1] - lcd_win[1]/2, 0])
            cube([lcd_win[0], lcd_win[1], top_h + zip_h]);
        // MQ-135 opening (left of the screen)
        translate([mq_pos[0], mq_pos[1], 0])
            cylinder(d = mq_d, h = top_h + zip_h);
        // DHT11 window (right of the screen)
        translate([dht_pos[0] - dht_win[0]/2, dht_pos[1] - dht_win[1]/2, 0])
            cube([dht_win[0], dht_win[1], top_h + zip_h]);
    }
}

// ---------- 4. SIMPLIFIED ELECTRONICS (preview only)
module lcd_module() {
    color([0.05, 0.45, 0.20]) translate([-40, -18, 0]) cube([80, 36, 1.6]);          // PCB
    color([0.06, 0.06, 0.07]) translate([-36.5, -13.5, 1.6]) cube([73, 27, 7]);      // bezel
    color([0.20, 0.45, 0.95]) translate([-32, -8, 8.65]) cube([64, 16, 0.2]);        // screen
}
// sensors point UP; z = 0 is the underside of the lid
module mq135() {
    color([0.70, 0.71, 0.73]) cylinder(d = 20, h = wall + 9);                       // mesh cap, 9 mm above the lid
    color([0.10, 0.10, 0.10]) translate([0, 0, -2]) cylinder(d = 24, h = 2);        // flange under the lid
    color([0.12, 0.30, 0.75]) translate([-13, -10, -3.6]) cube([26, 20, 1.6]);     // module PCB
}
module dht11() {
    color([0.30, 0.66, 0.92]) translate([-7.75, -10, 0]) cube([15.5, 20, wall + 6]); // grille, 6 mm above the lid
    color([0.12, 0.30, 0.75]) translate([-10, -13, -1.6]) cube([20, 26, 1.6]);      // module PCB
}
module esp32() {
    color([0.08, 0.08, 0.09]) cube([51, 28, 1.6]);
    color([0.72, 0.73, 0.75]) translate([30, 5, 1.6]) cube([18, 18, 3]);
}

// ---------- ASSEMBLY
bottom_half();
zipper_band();
translate([0, W/2, explode]) rotate([lid_open_angle, 0, 0]) translate([0, -W/2, 0]) {
    top_half();
    if (show_components) {
        translate([lcd_pos[0], lcd_pos[1], zip_h/2 + top_h - wall - 9.5]) lcd_module();
        translate([mq_pos[0],  mq_pos[1],  zip_h/2 + top_h - wall]) mq135();
        translate([dht_pos[0], dht_pos[1], zip_h/2 + top_h - wall]) dht11();
    }
}
if (show_components)
    translate([-25, 5, -zip_h/2 - bot_h + wall + 6]) esp32();
