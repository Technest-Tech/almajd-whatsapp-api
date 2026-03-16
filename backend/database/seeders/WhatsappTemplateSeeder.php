<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class WhatsappTemplateSeeder extends Seeder
{
    public function run(): void
    {
        $templates = [
            [
                'name' => 'class_start_reminder',
                'language' => 'en',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'class_start_reminder',
                'body_template' => "Assalamu Alaikum! 🌸\n\nJust a gentle reminder that your class is starting soon.\n\nPlease prepare your materials and be ready to join the classroom. May Allah make it a blessed session for you. 💻📖",
                'variables_schema' => json_encode([]),
            ],
            [
                'name' => 'student_late_alert',
                'language' => 'en',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'student_late_alert',
                'body_template' => "Assalamu Alaikum,\nYour class session has already started. \u{1F552}\n\nYour teacher is currently waiting for you in the classroom. We encourage you to join now so you don't miss out on the opening blessings of the lesson. \u{1F3C3}\u{200D}\u{2642}\u{FE0F}\u{2728}\n\nAlmajd Academy",
                'variables_schema' => json_encode([]),
            ],
            [
                'name' => 'class_completion_status',
                'language' => 'en',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'class_completion_status',
                'body_template' => "Class Summary - Almajd Academy 📝\n\nAlhamdulillah, your class session has ended. We hope it was a beneficial experience!\n\nJazakum Allah Khayran for your dedication to learning. May Allah reward you. 🌟\n\nTeachers, please remember to update the attendance status in the app. ✅❌",
                'variables_schema' => json_encode([]),
            ],
            [
                'name' => 'new_student_onboarding',
                'language' => 'ar',
                'category' => 'MARKETING',
                'status' => 'approved',
                'content_sid' => 'new_student_onboarding',
                'body_template' => "السلام عليكم ورحمة الله وبركاته 🌸\n\nWelcome to Almajd Academy. We are honored to assist you on your journey of learning. 📖\n\nWe are reaching out to see how we can best serve you. Are you interested in:\n\nBooking a trial session? ✨\n\nGetting subscription details? 📝\n\nAsking about our curriculum? 📚\n\nPlease let us know how we can help. May Allah grant you success and beneficial knowledge. 🤲\n\nJazakum Allah Khayran.",
                'variables_schema' => json_encode([]),
            ],
            [
                'name' => 'teacher_at_start_request',
                'language' => 'ar',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'teacher_at_start_request', // dummy local SID
                'body_template' => "🔔 حصة *{{1}}* تبدأ الآن!\n👤 الطالب: {{2}}\n\nهل انضم الطالب؟\nأرسل *1* = نعم\nأرسل *2* = لا",
                'variables_schema' => json_encode(['1' => 'string', '2' => 'string']),
            ],
            [
                'name' => 'teacher_after_5m_request',
                'language' => 'ar',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'teacher_after_5m_request',
                'body_template' => "⚠️ تنبيه: حصة *{{1}}* بدأت منذ 5 دقائق\n👤 الطالب: {{2}}\n\nمرت 5 دقائق. هل انضم الطالب؟\nأرسل *1* = نعم\nأرسل *2* = لا",
                'variables_schema' => json_encode(['1' => 'string', '2' => 'string']),
            ],
            [
                'name' => 'teacher_post_end_request',
                'language' => 'ar',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'teacher_post_end_request',
                'body_template' => "🏁 حصة *{{1}}* انتهى وقتها\n👤 الطالب: {{2}}\n\nهل اكتملت الحصة بنجاح؟\nأرسل *1* = نعم، اكتملت\nأرسل *2* = لا، لم تكتمل",
                'variables_schema' => json_encode(['1' => 'string', '2' => 'string']),
            ],
            [
                'name' => 'student_before_reminder',
                'language' => 'ar',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'student_before_reminder',
                'body_template' => "📚 تذكير: حصة *{{1}}* ستبدأ خلال 5 دقائق\n⏰ الوقت: {{2}}\n👨‍🏫 المعلم: {{3}}",
                'variables_schema' => json_encode(['1' => 'string', '2' => 'string', '3' => 'string']),
            ],
            [
                'name' => 'student_at_start_reminder',
                'language' => 'ar',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'student_at_start_reminder',
                'body_template' => "🔔 حصة *{{1}}* تبدأ الآن!\n👨‍🏫 المعلم: {{2}}\nيرجى الانضمام فوراً",
                'variables_schema' => json_encode(['1' => 'string', '2' => 'string']),
            ],
            [
                'name' => 'student_after_5m_alert',
                'language' => 'ar',
                'category' => 'UTILITY',
                'status' => 'approved',
                'content_sid' => 'student_after_5m_alert',
                'body_template' => "⚠️ تنبيه: حصة *{{1}}* بدأت منذ 5 دقائق\n👨‍🏫 المعلم: {{2}}\nيرجى الانضمام فوراً!",
                'variables_schema' => json_encode(['1' => 'string', '2' => 'string']),
            ]
        ];

        foreach ($templates as $template) {
            \App\Models\WhatsappTemplate::updateOrCreate(
                ['name' => $template['name']],
                $template
            );
        }
    }
}
