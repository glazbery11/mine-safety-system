// ==============================================================================
// 3D MODEL FOR AUTOCAD / TINKERCAD / 3D PRINTING
// PROJECT: IoT-Based Coal Mine Safety Monitoring & Real-Time Alerting System
// ENCLOSURE DIMENSIONS: 140mm (L) x 100mm (W) x 52mm (H)
// WALL THICKNESS: 3mm | MATERIAL: High-Impact Flame-Retardant ABS (IP65)
// ==============================================================================

$fn = 60;

box_length = 140;
box_width  = 100;
box_height = 40;
lid_height = 12;
wall_thick = 3.0;
corner_rad = 6.0;

// Rounded Box Module
module rounded_box(l, w, h, r) {
    hull() {
        translate([r, r, 0]) cylinder(r=r, h=h);
        translate([l-r, r, 0]) cylinder(r=r, h=h);
        translate([r, w-r, 0]) cylinder(r=r, h=h);
        translate([l-r, w-r, 0]) cylinder(r=r, h=h);
    }
}

// 1. MAIN ENCLOSURE BASE (Нижняя часть корпуса)
module enclosure_base() {
    difference() {
        // Outer Shell
        rounded_box(box_length, box_width, box_height, corner_rad);
        
        // Inner Cavity
        translate([wall_thick, wall_thick, wall_thick])
            rounded_box(box_length - 2*wall_thick, box_width - 2*wall_thick, box_height, corner_rad - 1);
            
        // USB Cable Gland Hole (Левый торец для питания ESP32 MicroUSB / Type-C)
        translate([-1, box_width/2 - 6, 8])
            cube([wall_thick + 2, 12, 8]);
    }
    
    // Internal Mounting Standoffs for ESP32 and Sensors (Стойки крепления плат M3)
    translate([25, 25, wall_thick]) cylinder(r=3.5, h=6);
    translate([75, 25, wall_thick]) cylinder(r=3.5, h=6);
    translate([25, 75, wall_thick]) cylinder(r=3.5, h=6);
    translate([75, 75, wall_thick]) cylinder(r=3.5, h=6);
}

// 2. TOP LID WITH COMPONENT CUTOUTS (Лицевая крышка с вырезами)
module enclosure_lid() {
    difference() {
        // Outer Lid
        rounded_box(box_length, box_width, lid_height, corner_rad);
        
        // Inner Lip
        translate([wall_thick, wall_thick, -1])
            rounded_box(box_length - 2*wall_thick, box_width - 2*wall_thick, lid_height - wall_thick + 1, corner_rad - 1);

        // --- CUTOUT 1: LCD 1602 Display (71.3mm x 26.3mm Window) ---
        translate([box_length/2 - 35.6, 20, -1])
            cube([71.3, 26.3, lid_height + 2]);

        // --- CUTOUT 2: MQ-135 Gas Sensor Air Intake (D = 20.5mm Circular Vent) ---
        translate([28, 75, -1])
            cylinder(d=20.5, h=lid_height + 2);

        // --- CUTOUT 3: DHT11 Ventilation Grille (4 Slits of 18mm x 2.2mm) ---
        for (i = [0 : 3]) {
            translate([85, 68 + i*4, -1])
                cube([18, 2.2, lid_height + 2]);
        }

        // --- CUTOUT 4: Active Buzzer Acoustic Port (6 holes of 2mm) ---
        translate([118, 75, -1]) {
            cylinder(d=2.5, h=lid_height + 2);
            translate([4, 0, 0]) cylinder(d=2.0, h=lid_height + 2);
            translate([-4, 0, 0]) cylinder(d=2.0, h=lid_height + 2);
            translate([0, 4, 0]) cylinder(d=2.0, h=lid_height + 2);
            translate([0, -4, 0]) cylinder(d=2.0, h=lid_height + 2);
        }
    }
}

// ASSEMBLED PREVIEW (Готовая сборка)
color([0.92, 0.55, 0.05, 0.9]) enclosure_base();
translate([0, 0, box_height + 5]) color([0.98, 0.72, 0.15, 0.95]) enclosure_lid();
