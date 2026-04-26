<?php
require '/var/www/almajd/backend/vendor/autoload.php';
$app = require_once '/var/www/almajd/backend/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\Teacher;
use App\Models\Student;
use App\Models\Guardian;

function sanitizePhone($phone) {
    if (!$phone) return null;
    // Remove all spaces, dashes, parentheses
    $clean = preg_replace('/[\s\-\(\)]+/', '', $phone);
    // Ensure it starts with +, if it doesn't but starts with country code, logic can be added, but for now just strip spaces.
    return trim($clean);
}

echo "Sanitizing and Syncing Teachers...\n";
$teachers = Teacher::whereNotNull('whatsapp_number')->get();
$t_count = 0;
foreach ($teachers as $teacher) {
    $clean = sanitizePhone($teacher->whatsapp_number);
    if (!$clean) continue;
    
    // Update the teacher's own number to be clean
    if ($clean !== $teacher->whatsapp_number) {
        $teacher->update(['whatsapp_number' => $clean]);
    }
    
    $guardian = Guardian::firstOrCreate(
        ['phone' => $clean],
        ['name' => $teacher->name]
    );
    
    if (in_array($guardian->name, ['Unknown Contact', $guardian->phone])) {
        $guardian->update(['name' => $teacher->name]);
    }
    $t_count++;
}
echo "Synced $t_count teachers.\n";

echo "Sanitizing and Syncing Students...\n";
$students = Student::whereNotNull('whatsapp_number')->get();
$s_count = 0;
foreach ($students as $student) {
    $clean = sanitizePhone($student->whatsapp_number);
    if (!$clean) continue;

    // Update the student's own number to be clean
    if ($clean !== $student->whatsapp_number) {
        $student->update(['whatsapp_number' => $clean]);
    }

    $guardian = Guardian::firstOrCreate(
        ['phone' => $clean],
        ['name' => $student->name]
    );

    if (in_array($guardian->name, ['Unknown Contact', $guardian->phone])) {
        $guardian->update(['name' => $student->name]);
    }
    $s_count++;
}
echo "Synced $s_count students.\n";

// Final cleanup: Delete any guardians that are just phone numbers IF there is a duplicate that has a real name
// (Optional, just to be safe)
