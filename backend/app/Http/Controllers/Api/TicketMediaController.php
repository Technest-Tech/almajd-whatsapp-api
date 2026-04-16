<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Ticket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class TicketMediaController extends Controller
{
    /**
     * Download or stream media for a ticket.
     * GET /api/media/tickets/{ticket}/{filename}
     */
    public function download(int $ticket, string $filename)
    {
        $path = 'tickets/' . $ticket . '/' . $filename;

        if (!Storage::disk('public')->exists($path)) {
            abort(404);
        }

        $mime = Storage::disk('public')->mimeType($path);

        return response()->file(Storage::disk('public')->path($path), [
            'Content-Type'        => $mime,
            'Content-Disposition' => 'inline; filename="' . $filename . '"',
        ]);
    }

    /**
     * Upload media (image, audio, document) for a specific ticket.
     * POST /api/tickets/{ticket}/upload
     *
     * Audio files are automatically converted to OGG/Opus format
     * so WhatsApp recipients can play them as native voice notes.
     */
    public function upload(Request $request, int $ticket): JsonResponse
    {
        $request->validate([
            'file' => 'required|file|max:20480', // limit to 20MB
        ]);

        $ticketModel = Ticket::findOrFail($ticket);
        $file        = $request->file('file');
        $mime        = $file->getMimeType() ?? '';
        $extension   = strtolower($file->getClientOriginalExtension() ?: 'bin');

        // ── Audio: convert to OGG/Opus for WhatsApp compatibility ─────────────
        $isAudio = str_contains($mime, 'audio')
            || in_array($extension, ['m4a', 'mp3', 'ogg', 'wav', 'aac', 'opus', 'webm'], true);

        if ($isAudio && $extension !== 'ogg') {
            $converted = $this->convertAudioToOgg($file->getRealPath());

            if ($converted !== null) {
                $filename = Str::ulid() . '.ogg';
                $path     = 'tickets/' . $ticketModel->id . '/' . $filename;
                Storage::disk('public')->put($path, file_get_contents($converted));
                @unlink($converted); // delete temp file

                return response()->json([
                    'status'  => 'success',
                    'message' => 'Audio converted and uploaded successfully',
                    'data'    => [
                        'media_url' => route('ticket.media.download', ['ticket' => $ticketModel->id, 'filename' => $filename]),
                        'mime_type' => 'audio/ogg; codecs=opus',
                        'size'      => Storage::disk('public')->size($path),
                    ],
                ], 201);
            }

            // Conversion failed — fall through and store original
            Log::warning('TicketMediaController: audio OGG conversion failed, storing original', [
                'ticket' => $ticket,
                'mime'   => $mime,
                'ext'    => $extension,
            ]);
        }

        // ── Non-audio or conversion failed: store as-is ───────────────────────
        $filename = Str::ulid() . '.' . $extension;
        $path     = $file->storeAs('tickets/' . $ticketModel->id, $filename, 'public');

        if (!$path) {
            return response()->json([
                'status'  => 'error',
                'message' => 'Failed to store the uploaded file.',
            ], 500);
        }

        return response()->json([
            'status'  => 'success',
            'message' => 'File uploaded successfully',
            'data'    => [
                'media_url' => route('ticket.media.download', ['ticket' => $ticketModel->id, 'filename' => $filename]),
                'mime_type' => $file->getMimeType(),
                'size'      => $file->getSize(),
            ],
        ], 201);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────

    /**
     * Convert any audio file to OGG/Opus using ffmpeg.
     * Returns the path to the temp OGG file, or null on failure.
     */
    private function convertAudioToOgg(string $inputPath): ?string
    {
        $outputPath = sys_get_temp_dir() . '/' . Str::ulid() . '.ogg';

        // -y          overwrite output without asking
        // -c:a libopus  encode with Opus codec (WhatsApp native voice format)
        // -b:a 64k    64kbps — excellent quality for voice
        // -vbr on     variable bitrate encoding
        // -application voip  tune encoder for voice
        $cmd = sprintf(
            'ffmpeg -y -i %s -c:a libopus -b:a 64k -vbr on -application voip %s 2>&1',
            escapeshellarg($inputPath),
            escapeshellarg($outputPath)
        );

        exec($cmd, $output, $returnCode);

        if ($returnCode !== 0 || !file_exists($outputPath) || filesize($outputPath) === 0) {
            Log::warning('ffmpeg audio conversion failed', [
                'cmd'    => $cmd,
                'output' => implode("\n", array_slice($output, -5)),
                'code'   => $returnCode,
            ]);
            return null;
        }

        return $outputPath;
    }
}
